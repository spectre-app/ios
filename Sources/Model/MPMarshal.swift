//
// Created by Maarten Billemont on 2019-05-11.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

class MPMarshal: Observable {
    public static let shared = MPMarshal()

    public let observers = Observers<MPMarshalObserver>()
    public var users: [UserInfo]? {
        didSet {
            if oldValue != self.users {
                self.observers.notify { $0.usersDidChange( self.users ) }
            }
        }
    }

    private var saving            = [ MPUser ]()
    private var reloadCompleted: Date?
    private let marshalQueue      = DispatchQueue( label: "marshal" )
    private let defaults          = UserDefaults( suiteName: "\(Bundle.main.bundleIdentifier ?? "mPass").marshal" )
    private let documentDirectory = (try? FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true ))

    // MARK: --- Interface ---

    public func setNeedsReload(completion: (([UserInfo]?) -> Void)? = nil) {
        let reloadRequested = Date()
        self.marshalQueue.asyncAfter( deadline: .now() + .milliseconds( 500 ) ) {
            if let reloadCompleted = self.reloadCompleted, reloadRequested < reloadCompleted {
                completion?( self.users )
            }
            else {
                self.doReload( completion: completion )
            }
        }
    }

    private func doReload(completion: (([UserInfo]?) -> Void)? = nil) {
        // Import legacy users
        self.importLegacy()

        // Reload users
        var users = [ UserInfo ]()
        for documentFile in self.userDocuments() {
            if let user = self.load( file: documentFile ) {
                users.append( user )
            }
        }
        self.reloadCompleted = Date()
        self.users = users

        if let completion = completion {
            DispatchQueue.main.perform {
                completion( self.users )
            }
        }
    }

    private func load(file documentFile: URL) -> UserInfo? {
        if let document = FileManager.default.contents( atPath: documentFile.path ) {
            return self.load( data: document, from: documentFile )
        }

        return nil
    }

    private func load(data document: Data, from documentFile: URL? = nil) -> UserInfo? {
        if let userDocument = String( data: document, encoding: .utf8 ),
           let userInfo = mpw_marshal_read_info( userDocument )?.pointee, userInfo.format != .none,
           let fullName = String( safeUTF8: userInfo.fullName ) {
            return UserInfo(
                    origin: documentFile,
                    document: userDocument,
                    format: userInfo.format,
                    exportDate: Date( timeIntervalSince1970: TimeInterval( userInfo.exportDate ) ),
                    redacted: userInfo.redacted,
                    algorithm: userInfo.algorithm,
                    avatar: MPUser.Avatar.decode( avatar: userInfo.avatar ),
                    fullName: fullName,
                    identicon: userInfo.identicon,
                    keyID: String( safeUTF8: userInfo.keyID ),
                    lastUsed: Date( timeIntervalSince1970: TimeInterval( userInfo.lastUsed ) )
            )
        }

        return nil
    }

    public func delete(userInfo: UserInfo) -> Bool {
        guard let userFile = userInfo.origin
        else {
            mperror( title: "Couldn't remove user document", context: "\(userInfo.fullName) has no origin" )
            return false
        }

        do {
            try FileManager.default.removeItem( at: userFile )
            self.users?.removeAll { $0 == userInfo }
            return true
        }
        catch {
            mperror( title: "Couldn't remove user document", context: userFile.lastPathComponent, error: error )
        }

        return false
    }

    public func setNeedsSave(user: MPUser) {
        guard !self.saving.contains( user )
        else {
            return
        }

        self.saving.append( user )
        self.marshalQueue.asyncAfter( deadline: .now() + .seconds( 1 ) ) {
            do {
                let destination = try self.save( user: user, format: .default )
                if let origin = user.origin, origin != destination,
                   FileManager.default.fileExists( atPath: origin.path ) {
                    do {
                        try FileManager.default.removeItem( at: origin )
                    }
                    catch {
                        mperror( title: "Cleanup issue", context: origin.lastPathComponent, error: error )
                    }
                }
                user.origin = destination
            }
            catch {
                mperror( title: "Issue saving", context: user.fullName, error: error )
            }
            self.saving.removeAll { $0 == user }
        }
    }

    @discardableResult
    public func save(user: MPUser, format: MPMarshalFormat, redacted: Bool = true, in directory: URL? = nil) throws -> URL {
        return try self.marshalQueue.await {
            return try DispatchQueue.mpw.await {
                guard let documentFile = self.file( for: user, in: directory, format: format )
                else {
                    throw Error.internal( details: "No path to marshal \(user)" )
                }
                if !FileManager.default.createFile( atPath: documentFile.path, contents:
                try self.export( user: user, format: format, redacted: redacted ) ) {
                    throw Error.internal( details: "Couldn't save \(documentFile)" )
                }

                self.setNeedsReload()
                return documentFile
            }
        }
    }

    public func export(user: MPUser, format: MPMarshalFormat, redacted: Bool) throws -> Data {
        return try DispatchQueue.mpw.await {
            try provideMasterKeyWith( key: user.masterKey ) { masterKeyProvider in
                guard let marshalledUser = mpw_marshal_user( user.fullName, masterKeyProvider, user.algorithm )
                else {
                    throw Error.internal( details: "Couldn't marshal \(user)" )
                }

                marshalledUser.pointee.redacted = redacted
                marshalledUser.pointee.avatar = user.avatar.encode()
                marshalledUser.pointee.identicon = user.identicon
                user.masterKeyID?.withCString { marshalledUser.pointee.keyID = UnsafePointer( mpw_strdup( $0 ) ) }
                marshalledUser.pointee.defaultType = user.defaultType
                marshalledUser.pointee.lastUsed = time_t( user.lastUsed.timeIntervalSince1970 )

                for site in user.sites {
                    guard let marshalledSite = mpw_marshal_site( marshalledUser, site.siteName, site.resultType, site.counter, site.algorithm )
                    else {
                        throw Error.internal( details: "Couldn't marshal \(user): \(site)" )
                    }

                    site.resultState?.withCString { marshalledSite.pointee.resultState = UnsafePointer( mpw_strdup( $0 ) ) }
                    marshalledSite.pointee.loginType = site.loginType
                    site.loginState?.withCString { marshalledSite.pointee.loginState = UnsafePointer( mpw_strdup( $0 ) ) }
                    site.url?.withCString { marshalledSite.pointee.url = UnsafePointer( mpw_strdup( $0 ) ) }
                    marshalledSite.pointee.uses = site.uses
                    marshalledSite.pointee.lastUsed = time_t( site.lastUsed.timeIntervalSince1970 )
                }

                var error    = MPMarshalError( type: .success, message: nil )
                let document = mpw_marshal_write( format, marshalledUser, &error )
                if error.type == .success {
                    if let document = document?.toStringAndDeallocate()?.data( using: .utf8 ) {
                        return document
                    }

                    throw Error.internal( details: "Missing marshal document" )
                }
                else {
                    throw Error.marshal( error: error )
                }
            }
        }
    }

    public func `import`(data: Data, completion: ((Bool) -> Void)? = nil) {
        DispatchQueue.mpw.perform {
            guard let importingUser = self.load( data: data )
            else {
                mperror( title: "Issue importing", context: "Not an \(PearlInfoPlist.get().cfBundleDisplayName ?? "mPass") import document" )
                completion?( false )
                return
            }
            guard let importingName = String( safeUTF8: importingUser.fullName )
            else {
                mperror( title: "Issue importing", context: "Import missing fullName" )
                completion?( false )
                return
            }
            guard let importingFile = self.file( named: importingName, format: importingUser.format )
            else {
                mperror( title: "Issue importing", context: "No path for \(importingName)" )
                completion?( false )
                return
            }

            if FileManager.default.fileExists( atPath: importingFile.path ),
               let existingUser = self.load( file: importingFile ) {
                self.import( data: data, from: importingUser, into: existingUser, completion: completion )
            }
            else {
                self.import( data: data, from: importingUser, into: importingFile, completion: completion )
            }
        }
    }

    private func `import`(data: Data, from importingUser: UserInfo, into existingUser: UserInfo, completion: ((Bool) -> Void)?) {
        DispatchQueue.main.perform {
            guard let viewController = UIApplication.shared.keyWindow?.rootViewController
            else {
                mperror( title: "Issue importing", context: "Could not present UI to handle import conflict." )
                completion?( false )
                return
            }

            let passwordField = MPMasterPasswordField( user: existingUser )
            let controller    = UIAlertController( title: "Merge Sites", message:
            """
            \(existingUser.fullName) already exists.

            Replacing will delete the existing user and replace it with the imported user.

            Merging will import only the new information from the import file into the existing user.
            """, preferredStyle: .alert )
            controller.addTextField { passwordField.passwordField = $0 }
            controller.addAction( UIAlertAction( title: "Cancel", style: .cancel ) { _ in
                completion?( false )
            } )
            controller.addAction( UIAlertAction( title: "Replace", style: .destructive ) { _ in
                if !passwordField.mpw_process(
                        handler: { importingUser.mpw_authenticate( masterPassword: $1 ).0 },
                        completion: { importedUser in
                            if importedUser == nil {
                                mperror( title: "Issue importing", context:
                                "Incorrect master password for import of \(importingUser.fullName)" )
                                viewController.present( controller, animated: true )
                            }
                            else if let existingFile = existingUser.origin {
                                if FileManager.default.fileExists( atPath: existingFile.path ) {
                                    do {
                                        try FileManager.default.removeItem( at: existingFile )
                                    }
                                    catch {
                                        mperror( title: "Issue replacing", context: "Couldn't remove \(existingFile.lastPathComponent)" )
                                    }
                                }

                                self.import( data: data, from: importingUser, into: existingFile, completion: completion )
                            }
                            else {
                                completion?( false )
                            }
                        } ) {
                    mperror( title: "Issue importing", context: "Missing master password" )
                    viewController.present( controller, animated: true )
                }
            } )
            controller.addAction( UIAlertAction( title: "Merge", style: .default ) { _ in
                let spinner = MPAlertView( title: "Unlocking", message: importingUser.description,
                                           content: UIActivityIndicatorView( activityIndicatorStyle: .whiteLarge ) )
                        .show( dismissAutomatically: false )

                if !passwordField.mpw_process(
                        handler: {
                            (importingUser.mpw_authenticate( masterPassword: $1 ).0,
                             existingUser.mpw_authenticate( masterPassword: $1 ).0)
                        },
                        completion: { users in
                            spinner.dismiss()

                            let (importedUser, existedUser) = users
                            if let importedUser = importedUser,
                               let existedUser = existedUser {
                                self.import( from: importedUser, into: existedUser, completion: completion )
                            }
                            else if let importedUser = importedUser {
                                let passwordField = MPMasterPasswordField( user: existingUser )
                                let controller    = UIAlertController( title: "Unlock Existing User", message:
                                """
                                The existing user is locked with a different master password.

                                The continue merging, also provide the existing user's master password.

                                Replacing will delete the existing user and replace it with the imported user.
                                """, preferredStyle: .alert )
                                controller.addTextField { field in
                                    passwordField.passwordField = field
                                }
                                controller.addAction( UIAlertAction( title: "Cancel", style: .cancel ) { _ in
                                    completion?( false )
                                } )
                                controller.addAction( UIAlertAction( title: "Replace", style: .destructive ) { _ in
                                    if let existingFile = existingUser.origin {
                                        if FileManager.default.fileExists( atPath: existingFile.path ) {
                                            do {
                                                try FileManager.default.removeItem( at: existingFile )
                                            }
                                            catch {
                                                mperror( title: "Issue replacing", context: "Couldn't remove \(existingFile.lastPathComponent)" )
                                            }
                                        }

                                        self.import( data: data, from: importingUser, into: existingFile, completion: completion )
                                    }
                                    else {
                                        completion?( false )
                                    }
                                } )
                                controller.addAction( UIAlertAction( title: "Merge", style: .default ) { _ in
                                    spinner.show( dismissAutomatically: false )

                                    if !passwordField.mpw_process(
                                            handler: { existingUser.mpw_authenticate( masterPassword: $1 ).0 },
                                            completion: { existedUser in
                                                spinner.dismiss()

                                                if let existedUser = existedUser {
                                                    self.import( from: importedUser, into: existedUser, completion: completion )
                                                }
                                                else {
                                                    mperror( title: "Issue importing", context:
                                                    "Incorrect master password for existing \(existingUser.fullName)" )
                                                    viewController.present( controller, animated: true )
                                                }
                                            } ) {
                                        mperror( title: "Issue importing", context: "Missing master password" )
                                        viewController.present( controller, animated: true )
                                    }
                                } )
                                viewController.present( controller, animated: true )
                            }
                            else if let existedUser = existedUser {
                                let passwordField = MPMasterPasswordField( user: importingUser )
                                let controller    = UIAlertController( title: "Unlock Import", message:
                                """
                                The import user is locked with a different master password.

                                The continue merging, also provide the imported user's master password.
                                """, preferredStyle: .alert )
                                controller.addTextField { field in
                                    passwordField.passwordField = field
                                }
                                controller.addAction( UIAlertAction( title: "Cancel", style: .cancel ) { _ in
                                    completion?( false )
                                } )
                                controller.addAction( UIAlertAction( title: "Merge", style: .default ) { _ in
                                    spinner.show( dismissAutomatically: false )

                                    if !passwordField.mpw_process(
                                            handler: { importingUser.mpw_authenticate( masterPassword: $1 ).0 },
                                            completion: { importedUser in
                                                spinner.dismiss()

                                                if let importedUser = importedUser {
                                                    self.import( from: importedUser, into: existedUser, completion: completion )
                                                }
                                                else {
                                                    mperror( title: "Issue importing", context:
                                                    "Incorrect master password for imported \(importingUser.fullName)" )
                                                    viewController.present( controller, animated: true )
                                                }
                                            } ) {
                                        mperror( title: "Issue importing", context: "Missing master password" )
                                        viewController.present( controller, animated: true )
                                    }
                                } )
                                viewController.present( controller, animated: true )
                            }
                            else {
                                mperror( title: "Issue importing", context: "Incorrect master password" )
                                viewController.present( controller, animated: true )
                            }
                        } ) {
                    mperror( title: "Issue importing", context: "Missing master password" )
                    viewController.present( controller, animated: true )
                }
            } )
            viewController.present( controller, animated: true )
        }
    }

    private func `import`(from importedUser: MPUser, into existedUser: MPUser, completion: ((Bool) -> Void)?) {
        let spinner = MPAlertView( title: "Merging", message: existedUser.description,
                                   content: UIActivityIndicatorView( activityIndicatorStyle: .whiteLarge ) )
                .show( dismissAutomatically: false )

        DispatchQueue.mpw.perform {
            var replacedSites = 0, newSites = 0
            for importedSite in importedUser.sites {
                if let existedSite = existedUser.sites.first( where: { $0.siteName == importedSite.siteName } ) {
                    if importedSite.lastUsed <= existedSite.lastUsed {
                        continue
                    }

                    existedUser.sites.removeAll { $0 === existedSite }
                    replacedSites += 1
                }
                else {
                    newSites += 1
                }

                existedUser.sites.append( importedSite.copy( for: existedUser ) )
            }
            var updatedUser = false
            if importedUser.lastUsed >= existedUser.lastUsed {
                existedUser.identicon = importedUser.identicon
                existedUser.avatar = importedUser.avatar
                existedUser.algorithm = importedUser.algorithm
                existedUser.defaultType = importedUser.defaultType
                existedUser.lastUsed = importedUser.lastUsed
                existedUser.masterKeyID = importedUser.masterKeyID
                updatedUser = true
            }

            DispatchQueue.main.perform {
                completion?( true )
                spinner.dismiss()

                if !updatedUser && replacedSites + newSites == 0 {
                    MPAlertView( title: "Import Skipped", message: existedUser.description, details:
                    """
                    The import into \(existedUser) was skipped.

                    This merge import contained no information that was either new or missing for the existing user.
                    """ ).show()
                }
                else {
                    MPAlertView( title: "Import Complete", message: existedUser.description, details:
                    """
                    Completed the import of sites into \(existedUser).

                    This was a merge import.  \(replacedSites) sites were replaced, \(newSites) new sites were created.
                    \(updatedUser ?
                            "The user settings were updated from the import.":
                            "The existing user's settings were more recent than the import.")
                    """ ).show()
                }
                self.setNeedsReload()
            }
        }
    }

    private func `import`(data: Data, from importingUser: UserInfo, into documentFile: URL, completion: ((Bool) -> Void)?) {
        let spinner = MPAlertView( title: "Replacing", message: documentFile.lastPathComponent,
                                   content: UIActivityIndicatorView( activityIndicatorStyle: .whiteLarge ) )
                .show( dismissAutomatically: false )

        DispatchQueue.mpw.perform {
            if !FileManager.default.createFile( atPath: documentFile.path, contents: data ) {
                mperror( title: "Issue importing", context: "Couldn't save \(documentFile.lastPathComponent)" )
                completion?( false )
                return
            }

            DispatchQueue.main.perform {
                completion?( true )
                spinner.dismiss()

                MPAlertView( title: "Import Complete", message: documentFile.lastPathComponent, details:
                """
                Completed the import of \(importingUser) (\(importingUser.format)).
                This export file was created on \(importingUser.exportDate).

                This was a direct installation of the import data, not a merge import.
                """ ).show()
                self.setNeedsReload()
            }
        }
    }

    @discardableResult
    private func importLegacy() -> Bool {
        return MPCoreData.shared.perform( async: false ) { context in
            do {
                for user: MPUserEntity_CoreData in try context.fetch( MPUserEntity.fetchRequest() ) {
                    guard let objectID = (user as? NSManagedObject)?.objectID, !objectID.isTemporaryID
                    else {
                        // Not a (saved) object.
                        continue
                    }
                    guard !(self.defaults?.bool( forKey: objectID.uriRepresentation().absoluteString ) ?? false)
                    else {
                        // Already imported.
                        continue
                    }
                    guard let fullName = user.name
                    else {
                        // Has no full name.
                        continue
                    }
                    guard let documentFile = self.file( named: fullName, format: .default )
                    else {
                        // Cannot be saved.
                        continue
                    }
                    try FileManager.default.createDirectory(
                            at: documentFile.deletingLastPathComponent(), withIntermediateDirectories: true )

                    var algorithm = MPAlgorithmVersion.versionCurrent
                    if let userAlgorithm = user.version_??.uint32Value,
                       let userAlgorithmValue = MPAlgorithmVersion( rawValue: userAlgorithm ) {
                        algorithm = userAlgorithmValue
                    }
                    var defaultType = MPResultType.default
                    if let userDefaultType = user.defaultType_?.uint32Value,
                       let userDefaultTypeValue = MPResultType( rawValue: userDefaultType ) {
                        defaultType = userDefaultTypeValue
                    }

                    guard let marshalledUser = mpw_marshal_user( fullName, nil, algorithm )
                    else {
                        throw Error.internal( details: "Couldn't allocate to marshal \(fullName)" )
                    }
                    marshalledUser.pointee.redacted = true
                    marshalledUser.pointee.avatar = user.avatar_?.uint32Value ?? 0
                    user.keyID?.hexEncodedString().withCString { marshalledUser.pointee.keyID = UnsafePointer( mpw_strdup( $0 ) ) }
                    marshalledUser.pointee.defaultType = defaultType
                    marshalledUser.pointee.lastUsed = Int( user.lastUsed?.timeIntervalSince1970 ?? 0 )

                    for site: MPSiteEntity_CoreData in user.sites ?? [] {
                        guard let siteName = site.name
                        else {
                            // Has no site name.
                            continue
                        }

                        var counter = MPCounterValue.initial
                        if let site = site as? MPGeneratedSiteEntity,
                           let siteCounter = site.counter_?.uint32Value,
                           let siteCounterValue = MPCounterValue( rawValue: siteCounter ) {
                            counter = siteCounterValue
                        }
                        var type = defaultType
                        if let siteType = site.type_?.uint32Value,
                           let siteTypeValue = MPResultType( rawValue: siteType ) {
                            type = siteTypeValue
                        }
                        var algorithm = algorithm
                        if let siteAlgorithm = site.version_?.uint32Value,
                           let siteAlgorithmValue = MPAlgorithmVersion( rawValue: siteAlgorithm ) {
                            algorithm = siteAlgorithmValue
                        }

                        guard let marshalledSite = mpw_marshal_site( marshalledUser, siteName, type, counter, algorithm )
                        else {
                            throw Error.internal( details: "Couldn't allocate to marshal \(fullName): \(siteName)" )
                        }
                        (site as? MPStoredSiteEntity)?.contentObject?.base64EncodedString().withCString {
                            marshalledSite.pointee.resultState = UnsafePointer( mpw_strdup( $0 ) )
                        }
                        marshalledSite.pointee.loginType = (site.loginGenerated_?.boolValue ?? true) ? .templateName: .statefulPersonal
                        site.loginName?.withCString { marshalledSite.pointee.loginState = UnsafePointer( mpw_strdup( $0 ) ) }
                        site.url??.withCString { marshalledSite.pointee.url = UnsafePointer( mpw_strdup( $0 ) ) }
                        marshalledSite.pointee.uses = site.uses_?.uint32Value ?? 0
                        marshalledSite.pointee.lastUsed = Int( site.lastUsed?.timeIntervalSince1970 ?? 0 )

                        for siteQuestion in site.questions?.seq( MPSiteQuestionEntity_CoreData.self ) ?? [] {
                            guard mpw_marshal_question( marshalledSite, siteQuestion.keyword ) != nil
                            else {
                                throw Error.internal( details: "Couldn't allocate to marshal \(fullName): \(siteName): \(String( safeUTF8: siteQuestion.keyword ) ?? "-")" )
                            }
                        }
                    }

                    var error    = MPMarshalError( type: .success, message: nil )
                    let document = mpw_marshal_write( .default, marshalledUser, &error )
                    if error.type == .success,
                       let document = document?.toStringAndDeallocate()?.data( using: .utf8 ) {
                        self.import( data: document ) { success in
                            if success {
                                self.defaults?.set( true, forKey: objectID.uriRepresentation().absoluteString )
                            }
                        }
                    }
                    else {
                        throw Error.marshal( error: error )
                    }
                }
            }
            catch {
                mperror( title: "Couldn't load legacy users", error: error )
            }
        }
    }

    private func userDocuments() -> [URL] {
        guard let documentsDirectory = self.documentDirectory
        else {
            mperror( title: "Couldn't find user documents" )
            return []
        }

        do {
            return try FileManager.default.contentsOfDirectory( atPath: documentsDirectory.path ).compactMap {
                documentsDirectory.appendingPathComponent( $0 )
            }
        }
        catch {
            // TODO: handle error
            mperror( title: "Couldn't access user documents", error: error )
            return []
        }
    }

    private func file(for user: MPUser, in directory: URL? = nil, format: MPMarshalFormat) -> URL? {
        return self.file( named: user.fullName, in: directory, format: format )
    }

    private func file(named name: String, in directory: URL? = nil, format: MPMarshalFormat) -> URL? {
        return DispatchQueue.mpw.await {
            if let formatExtension = String( safeUTF8: mpw_marshal_format_extension( format ) ),
               let directory = directory ?? self.documentDirectory {
                return directory.appendingPathComponent( name, isDirectory: false )
                                .appendingPathExtension( formatExtension )
            }

            return nil
        }
    }

    // MARK: --- Types ---

    enum Error: Swift.Error {
        case `internal`(details: String)
        case marshal(error: MPMarshalError)
    }

    class ActivityItem: NSObject, UIActivityItemSource {
        let user:     MPUser
        let format:   MPMarshalFormat
        let redacted: Bool
        var cleanup = [ URL ]()

        init(user: MPUser, format: MPMarshalFormat, redacted: Bool) {
            self.user = user
            self.format = format
            self.redacted = redacted
        }

        func text() -> String {
            let appName    = PearlInfoPlist.get().cfBundleDisplayName ?? "mPass"
            let appVersion = PearlInfoPlist.get().cfBundleShortVersionString ?? "-"
            let appBuild   = PearlInfoPlist.get().cfBundleVersion ?? "-"

            if self.redacted {
                return """
                       \(appName) export file (\(self.format)) for \(self.user)
                       NOTE: This is a SECURE export; access to the file does not expose its secrets.
                       ---
                       \(appName) v\(appVersion) (\(appBuild))
                       """
            }
            else {
                return """
                       \(appName) export (\(self.format)) for \(self.user)
                       NOTE: This export file's passwords are REVEALED.  Keep it safe!
                       ---
                       \(appName) v\(appVersion) (\(appBuild))
                       """
            }
        }

        func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
            return self.user.description
        }

        func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
            do {
                let exportFile = try MPMarshal.shared.save( user: self.user, format: self.format, redacted: self.redacted,
                                                            in: URL( fileURLWithPath: NSTemporaryDirectory() ) )
                self.cleanup.append( exportFile )
                return exportFile
            }
            catch {
                mperror( title: "Issue exporting", context: self.user.fullName, error: error )
                return nil
            }
        }

        func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
            return self.format.uti ?? ""
        }

        func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
            return "\(PearlInfoPlist.get().cfBundleDisplayName ?? "") Export: \(self.user.fullName)"
        }

        func activityViewController(_ activityViewController: UIActivityViewController, thumbnailImageForActivityType activityType: UIActivity.ActivityType?, suggestedSize size: CGSize) -> UIImage? {
            return self.user.avatar.image()
        }

        func activityViewController(_ activityViewController: UIActivityViewController, completed: Bool, forActivityType activityType: UIActivity.ActivityType?, returnedItems: [Any]?, activityError error: Swift.Error?) {
            self.cleanup.removeAll {
                nil != (try? FileManager.default.removeItem( at: $0 ))
            }
        }
    }

    class UserInfo: Equatable, CustomStringConvertible {
        public let origin:   URL?
        public let document: String

        public let format:     MPMarshalFormat
        public let exportDate: Date
        public let redacted:   Bool

        public let algorithm: MPAlgorithmVersion
        public let avatar:    MPUser.Avatar
        public let fullName:  String
        public let identicon: MPIdenticon
        public let keyID:     String?
        public let lastUsed:  Date

        public var resetKey = false

        init(origin: URL?, document: String, format: MPMarshalFormat, exportDate: Date, redacted: Bool,
             algorithm: MPAlgorithmVersion, avatar: MPUser.Avatar, fullName: String, identicon: MPIdenticon, keyID: String?, lastUsed: Date) {
            self.origin = origin
            self.document = document
            self.format = format
            self.exportDate = exportDate
            self.redacted = redacted
            self.algorithm = algorithm
            self.avatar = avatar
            self.fullName = fullName
            self.identicon = identicon
            self.keyID = keyID
            self.lastUsed = lastUsed
        }

        public func mpw_authenticate(masterPassword: String) -> (MPUser?, MPMarshalError) {
            return DispatchQueue.mpw.await {
                provideMasterKeyWith( password: masterPassword ) { masterKeyProvider in
                    var error = MPMarshalError( type: .success, message: nil )
                    if let marshalledUser = mpw_marshal_read(
                            self.document, self.format, self.resetKey ? nil: masterKeyProvider, &error )?.pointee,
                       error.type == .success {
                        let user = MPUser(
                                algorithm: marshalledUser.algorithm,
                                avatar: MPUser.Avatar.decode( avatar: marshalledUser.avatar ),
                                fullName: String( safeUTF8: marshalledUser.fullName ) ?? self.fullName,
                                identicon: marshalledUser.identicon,
                                masterKeyID: self.resetKey ? nil: self.keyID,
                                defaultType: marshalledUser.defaultType,
                                lastUsed: Date( timeIntervalSince1970: TimeInterval( marshalledUser.lastUsed ) ),
                                origin: self.origin
                        )

                        guard user.mpw_authenticate( masterPassword: masterPassword )
                        else {
                            return (nil, MPMarshalError( type: .errorMasterPassword, message: nil ))
                        }

                        for s in 0..<marshalledUser.sites_count {
                            let site = (marshalledUser.sites + s).pointee
                            if let siteName = String( safeUTF8: site.siteName ) {
                                user.sites.append( MPSite(
                                        user: user,
                                        siteName: siteName,
                                        algorithm: site.algorithm,
                                        counter: site.counter,
                                        resultType: site.resultType,
                                        resultState: String( safeUTF8: site.resultState ),
                                        loginType: site.loginType,
                                        loginState: String( safeUTF8: site.loginState ),
                                        url: String( safeUTF8: site.url ),
                                        uses: site.uses,
                                        lastUsed: Date( timeIntervalSince1970: TimeInterval( site.lastUsed ) )
                                ) )
                            }
                        }
                        return (user, error)
                    }

                    return (nil, error)
                }
            }
        }

        // MARK: --- Equatable ---

        static func ==(lhs: UserInfo, rhs: UserInfo) -> Bool {
            return lhs.fullName == rhs.fullName
        }

        // MARK: --- CustomStringConvertible ---

        var description: String {
            get {
                if let identicon = self.identicon.encoded() {
                    return "\(self.fullName): \(identicon)"
                }
                else if let keyID = self.keyID {
                    return "\(self.fullName): \(keyID)"
                }
                else {
                    return "\(self.fullName)"
                }
            }
        }
    }
}

extension MPMarshalError: CustomStringConvertible {
    public var description: String {
        return "\(self.type.rawValue): \(String( safeUTF8: self.message ) ?? "-")"
    }
}

protocol MPMarshalObserver {
    func usersDidChange(_ users: [MPMarshal.UserInfo]?)
}

private var currentMasterKey:      MPMasterKey?
private var currentMasterPassword: String?

private func __masterKeyObjectProvider(_ algorithm: MPAlgorithmVersion, _ fullName: UnsafePointer<CChar>?) -> MPMasterKey? {
    if let currentMasterKey = currentMasterKey {
        let providedMasterKey = UnsafeMutablePointer<UInt8>.allocate( capacity: MPMasterKeySize )
        providedMasterKey.initialize( from: currentMasterKey, count: MPMasterKeySize )
        return UnsafePointer<UInt8>( providedMasterKey )
    }

    return nil
}

private func __masterKeyPasswordProvider(_ algorithm: MPAlgorithmVersion, _ fullName: UnsafePointer<CChar>?) -> MPMasterKey? {
    return mpw_master_key( fullName, currentMasterPassword, algorithm )
}

private func provideMasterKeyWith<R>(key: MPMasterKey?, _ perform: (@escaping MPMasterKeyProvider) throws -> R) rethrows -> R {
    currentMasterKey = key
    defer {
        currentMasterKey = nil
    }

    return try perform( __masterKeyObjectProvider )
}

private func provideMasterKeyWith<R>(password: String?, _ perform: (@escaping MPMasterKeyProvider) throws -> R) rethrows -> R {
    currentMasterPassword = password
    defer {
        currentMasterPassword = nil
    }

    return try perform( __masterKeyPasswordProvider )
}
