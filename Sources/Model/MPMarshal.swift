//
// Created by Maarten Billemont on 2019-05-11.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

class MPMarshal: Observable {
    public static let shared = MPMarshal()

    public let observers = Observers<MPMarshalObserver>()
    public var userFiles: [UserFile]? {
        didSet {
            if oldValue != self.userFiles {
                self.observers.notify { $0.userFilesDidChange( self.userFiles ) }
            }
        }
    }

    private var saving            = [ MPUser ]()
    private let marshalQueue      = DispatchQueue( label: "marshal" )
    private let defaults          = UserDefaults( suiteName: "\(Bundle.main.bundleIdentifier ?? productName).marshal" )
    private let documentDirectory = (try? FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true ))
    private lazy var reloadTask = DispatchTask( queue: self.marshalQueue, qos: .userInitiated, deadline: .now() + .milliseconds( 300 ) ) {
        self.doReload()
    }

    // MARK: --- Interface ---

    @discardableResult
    public func setNeedsReload() -> Bool {
        self.reloadTask.request()
    }

    private func doReload() {
        // Import legacy users
        _ = try? self.importLegacy().await()

        // Reload users
        self.userFiles = self.userDocuments().compactMap { self.userFile( at: $0 ) }
    }

    private func userFile(at documentURL: URL) -> UserFile? {
        if let document = FileManager.default.contents( atPath: documentURL.path ) {
            return self.userFile( for: document, at: documentURL )
        }

        return nil
    }

    private func userFile(for document: Data, at documentFile: URL? = nil) -> UserFile? {
        UserFile( origin: documentFile, document: String( data: document, encoding: .utf8 ) )
    }

    public func delete(userFile: UserFile) -> Bool {
        guard let userURL = userFile.origin
        else {
            mperror( title: "Couldn't remove user document", context: "\(userFile.fullName) has no origin" )
            return false
        }

        do {
            try FileManager.default.removeItem( at: userURL )
            self.userFiles?.removeAll { $0 == userFile }
            return true
        }
        catch {
            mperror( title: "Couldn't remove user document", context: userURL.lastPathComponent, error: error )
        }

        return false
    }

    public func setNeedsSave(user: MPUser) {
        guard user.dirty, !self.saving.contains( user )
        else { return }

        self.saving.append( user )
        self.marshalQueue.asyncAfter( deadline: .now() + .seconds( 1 ) ) {
            guard user.masterKeyFactory != nil
            else { return }

            self.save( user: user, format: .default ).then( {
                switch $0 {
                    case .success(let destination):
                        if let origin = user.origin, origin != destination,
                           FileManager.default.fileExists( atPath: origin.path ) {
                            do { try FileManager.default.removeItem( at: origin ) }
                            catch { mperror( title: "Cleanup issue", context: origin.lastPathComponent, error: error ) }
                        }
                        user.origin = destination

                    case .failure(let error):
                        mperror( title: "Issue saving", context: user.fullName, error: error )
                }
                self.saving.removeAll { $0 == user }
            } )
        }
    }

    @discardableResult
    public func save(user: MPUser, format: MPMarshalFormat, redacted: Bool = true, in directory: URL? = nil) -> Promise<URL> {
        self.marshalQueue.promise {
            guard let documentURL = self.url( for: user, in: directory, format: format )
            else { throw MPError.internal( details: "No path to marshal \(user)" ) }

            return self.export( user: user, format: format, redacted: redacted ).then( { (data: Data) in
                if !FileManager.default.createFile( atPath: documentURL.path, contents: data ) {
                    throw MPError.internal( details: "Couldn't save \(documentURL)" )
                }

                self.setNeedsReload()
                return documentURL
            } )
        }
    }

    public func export(user: MPUser, format: MPMarshalFormat, redacted: Bool) -> Promise<Data> {
        DispatchQueue.mpw.promise { () -> Data in
            guard let keyFactory = user.masterKeyFactory
            else { throw MPMarshalError( type: MPMarshalErrorType.errorMissing, message: "Missing master key." ) }
            guard let marshalledUser = mpw_marshal_user( user.fullName, keyFactory.provide(), user.algorithm )
            else { throw MPError.internal( details: "Couldn't allocate for marshalling \(user)" ) }

            marshalledUser.pointee.redacted = redacted
            marshalledUser.pointee.avatar = user.avatar.encode()
            marshalledUser.pointee.identicon = user.identicon
            marshalledUser.pointee.keyID = UnsafePointer( mpw_strdup( user.masterKeyID ) )
            marshalledUser.pointee.defaultType = user.defaultType
            marshalledUser.pointee.lastUsed = time_t( user.lastUsed.timeIntervalSince1970 )

            for site in user.sites {
                guard let marshalledSite = mpw_marshal_site( marshalledUser, site.siteName, site.resultType, site.counter, site.algorithm )
                else { throw MPError.internal( details: "Couldn't marshal \(user): \(site)" ) }

                marshalledSite.pointee.resultState = UnsafePointer( mpw_strdup( site.resultState ) )
                marshalledSite.pointee.loginType = site.loginType
                marshalledSite.pointee.loginState = UnsafePointer( mpw_strdup( site.loginState ) )
                marshalledSite.pointee.url = UnsafePointer( mpw_strdup( site.url ) )
                marshalledSite.pointee.uses = site.uses
                marshalledSite.pointee.lastUsed = time_t( site.lastUsed.timeIntervalSince1970 )
            }

            if let data = String( safeUTF8: mpw_marshal_write( format, user.file, marshalledUser ),
                                  deallocate: true )?.data( using: .utf8 ),
               user.file.pointee.error.type == .success {
                return data
            }

            throw user.file.pointee.error
        }
    }

    @discardableResult
    public func `import`(data: Data) -> Promise<Bool> {
        DispatchQueue.mpw.promise {
            guard let importingFile = self.userFile( for: data )
            else {
                mperror( title: "Issue importing", context: "Not an \(PearlInfoPlist.get().cfBundleDisplayName ?? productName) import document" )
                return Promise( .success( false ) )
            }
            guard let importingName = String( safeUTF8: importingFile.fullName )
            else {
                mperror( title: "Issue importing", context: "Import missing fullName" )
                return Promise( .success( false ) )
            }
            guard let importingURL = self.url( for: importingName, format: importingFile.format )
            else {
                mperror( title: "Issue importing", context: "No path for \(importingName)" )
                return Promise( .success( false ) )
            }

            if FileManager.default.fileExists( atPath: importingURL.path ),
               let existingFile = self.userFile( at: importingURL ) {
                return self.import( data: data, from: importingFile, into: existingFile )
            }
            else {
                return self.import( data: data, from: importingFile, into: importingURL )
            }
        }
    }

    private func `import`(data: Data, from importingFile: UserFile, into existingFile: UserFile) -> Promise<Bool> {
        DispatchQueue.main.promise {
            guard let viewController = UIApplication.shared.keyWindow?.rootViewController
            else {
                mperror( title: "Issue importing", context: "Could not present UI to handle import conflict." )
                return Promise( .success( false ) )
            }

            let promise       = Promise<Bool>()
            let spinner       = MPAlert( title: "Unlocking", message: importingFile.description,
                                         content: UIActivityIndicatorView( style: .whiteLarge ) )
            let passwordField = MPMasterPasswordField( userFile: existingFile )
            let controller    = UIAlertController( title: "Merge Sites", message:
            """
            \(existingFile.fullName) already exists.

            Replacing will delete the existing user and replace it with the imported user.

            Merging will import only the new information from the import file into the existing user.
            """, preferredStyle: .alert )
            controller.addTextField { passwordField.passwordField = $0 }
            controller.addAction( UIAlertAction( title: "Cancel", style: .cancel ) { _ in
                promise.finish( .success( false ) )
            } )
            controller.addAction( UIAlertAction( title: "Replace", style: .destructive ) { _ in
                guard let authentication = passwordField.authenticate( { keyFactory in
                    importingFile.mpw_authenticate( keyFactory: keyFactory )
                } )
                else {
                    mperror( title: "Issue importing", context: "Missing master password" )
                    viewController.present( controller, animated: true )
                    return
                }

                spinner.show( dismissAutomatically: false )
                authentication.then( {
                    spinner.dismiss()

                    switch $0 {
                        case .success:
                            if let existingFile = existingFile.origin {
                                if FileManager.default.fileExists( atPath: existingFile.path ) {
                                    do {
                                        try FileManager.default.removeItem( at: existingFile )
                                    }
                                    catch {
                                        mperror( title: "Issue replacing", context: "Couldn't remove \(existingFile.lastPathComponent)" )
                                    }
                                }

                                self.import( data: data, from: importingFile, into: existingFile ).then { promise.finish( $0 ) }
                            }
                            else {
                                promise.finish( .success( false ) )
                            }

                        case .failure(let error):
                            mperror( title: "Issue importing", context: error.localizedDescription )
                            viewController.present( controller, animated: true )
                    }
                } )
            } )
            controller.addAction( UIAlertAction( title: "Merge", style: .default ) { _ in
                guard let authentication = passwordField.authenticate( { keyFactory in
                    Promise( .success(
                            (try? importingFile.mpw_authenticate( keyFactory: keyFactory ).await(),
                             try? existingFile.mpw_authenticate( keyFactory: keyFactory ).await()) ) )
                } )
                else {
                    mperror( title: "Issue importing", context: "Missing master password" )
                    viewController.present( controller, animated: true )
                    return
                }

                spinner.show( dismissAutomatically: false )
                authentication.then( on: .main ) {
                    spinner.dismiss()

                    switch $0 {
                        case .success(let (importedUser, existedUser)):
                            if let importedUser = importedUser,
                               let existedUser = existedUser {
                                self.import( from: importedUser, into: existedUser ).then { promise.finish( $0 ) }
                            }
                            else if let importedUser = importedUser {
                                let passwordField = MPMasterPasswordField( userFile: existingFile )
                                let controller    = UIAlertController( title: "Unlock Existing User", message:
                                """
                                The existing user is locked with a different master password.

                                The continue merging, also provide the existing user's master password.

                                Replacing will delete the existing user and replace it with the imported user.
                                """, preferredStyle: .alert )
                                controller.addTextField { passwordField.passwordField = $0 }
                                controller.addAction( UIAlertAction( title: "Cancel", style: .cancel ) { _ in
                                    promise.finish( .success( false ) )
                                } )
                                controller.addAction( UIAlertAction( title: "Replace", style: .destructive ) { _ in
                                    if let existingFile = existingFile.origin {
                                        if FileManager.default.fileExists( atPath: existingFile.path ) {
                                            do {
                                                try FileManager.default.removeItem( at: existingFile )
                                            }
                                            catch {
                                                mperror( title: "Issue replacing", context: "Couldn't remove \(existingFile.lastPathComponent)" )
                                            }
                                        }

                                        self.import( data: data, from: importingFile, into: existingFile ).then { promise.finish( $0 ) }
                                    }
                                    else {
                                        promise.finish( .success( false ) )
                                    }
                                } )
                                controller.addAction( UIAlertAction( title: "Merge", style: .default ) { _ in
                                    guard let authentication = passwordField.authenticate( { keyFactory in
                                        existingFile.mpw_authenticate( keyFactory: keyFactory )
                                    } )
                                    else {
                                        mperror( title: "Issue importing", context: "Missing master password" )
                                        viewController.present( controller, animated: true )
                                        return
                                    }

                                    spinner.show( dismissAutomatically: false )
                                    authentication.then( {
                                        spinner.dismiss()

                                        switch $0 {
                                            case .success(let existedUser):
                                                self.import( from: importedUser, into: existedUser ).then { promise.finish( $0 ) }

                                            case .failure(let error):
                                                mperror( title: "Issue importing", context: existingFile.fullName, details: error.localizedDescription )
                                                viewController.present( controller, animated: true )
                                        }
                                    } )
                                } )
                                viewController.present( controller, animated: true )
                            }
                            else if let existedUser = existedUser {
                                let passwordField = MPMasterPasswordField( userFile: importingFile )
                                let controller    = UIAlertController( title: "Unlock Import", message:
                                """
                                The import user is locked with a different master password.

                                The continue merging, also provide the imported user's master password.
                                """, preferredStyle: .alert )
                                controller.addTextField { passwordField.passwordField = $0 }
                                controller.addAction( UIAlertAction( title: "Cancel", style: .cancel ) { _ in
                                    promise.finish( .success( false ) )
                                } )
                                controller.addAction( UIAlertAction( title: "Merge", style: .default ) { _ in
                                    guard let authentication = passwordField.authenticate( { keyFactory in
                                        importingFile.mpw_authenticate( keyFactory: keyFactory )
                                    } )
                                    else {
                                        mperror( title: "Issue importing", context: "Missing master password" )
                                        viewController.present( controller, animated: true )
                                        return
                                    }

                                    spinner.show( dismissAutomatically: false )
                                    authentication.then( {
                                        spinner.dismiss()

                                        switch $0 {
                                            case .success(let importedUser):
                                                self.import( from: importedUser, into: existedUser ).then { promise.finish( $0 ) }

                                            case .failure(let error):
                                                mperror( title: "Issue importing", context: importingFile.fullName, details: error.localizedDescription )
                                                viewController.present( controller, animated: true )
                                        }
                                    } )
                                } )
                                viewController.present( controller, animated: true )
                            }
                            else {
                                mperror( title: "Issue importing", context: "Incorrect master password" )
                                viewController.present( controller, animated: true )
                            }

                        case .failure(let error):
                            mperror( title: "Issue importing", context: error.localizedDescription )
                            viewController.present( controller, animated: true )
                    }
                }
            } )

            viewController.present( controller, animated: true )
            return promise
        }
    }

    private func `import`(from importedUser: MPUser, into existedUser: MPUser) -> Promise<Bool> {
        let spinner = MPAlert( title: "Merging", message: existedUser.description,
                               content: UIActivityIndicatorView( style: .whiteLarge ) )

        spinner.show( dismissAutomatically: false )
        return DispatchQueue.mpw.promise {
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

            return DispatchQueue.main.promise { () -> Bool in
                spinner.dismiss()

                if !updatedUser && replacedSites + newSites == 0 {
                    MPAlert( title: "Import Skipped", message: existedUser.description, details:
                    """
                    The import into \(existedUser) was skipped.

                    This merge import contained no information that was either new or missing for the existing user.
                    """ ).show()
                }
                else {
                    MPAlert( title: "Import Complete", message: existedUser.description, details:
                    """
                    Completed the import of sites into \(existedUser).

                    This was a merge import.  \(replacedSites) sites were replaced, \(newSites) new sites were created.
                    \(updatedUser ?
                            "The user settings were updated from the import.":
                            "The existing user's settings were more recent than the import.")
                    """ ).show()
                }
                self.setNeedsReload()
                return true
            }
        }
    }

    private func `import`(data: Data, from importingFile: UserFile, into documentURL: URL) -> Promise<Bool> {
        let spinner = MPAlert( title: "Replacing", message: documentURL.lastPathComponent,
                               content: UIActivityIndicatorView( style: .whiteLarge ) )

        spinner.show( dismissAutomatically: false )
        return DispatchQueue.mpw.promise {
            if !FileManager.default.createFile( atPath: documentURL.path, contents: data ) {
                mperror( title: "Issue importing", context: "Couldn't save \(documentURL.lastPathComponent)" )
                return Promise( .success( false ) )
            }

            return DispatchQueue.main.promise { () -> Bool in
                spinner.dismiss()

                MPAlert( title: "Import Complete", message: documentURL.lastPathComponent, details:
                """
                Completed the import of \(importingFile) (\(importingFile.format)).
                This export file was created on \(importingFile.exportDate).

                This was a direct installation of the import data, not a merge import.
                """ ).show()
                self.setNeedsReload()

                return true
            }
        }
    }

    public func hasLegacy() -> Promise<Bool> {
        MPCoreData.shared.promise {
            (try $0.count( for: MPUserEntity.fetchRequest() )) > 0
        } ?? Promise( .success( false ) )
    }

    @discardableResult
    public func importLegacy(force: Bool = false) -> Promise<Bool> {
        MPCoreData.shared.promise { context -> Promise<Bool> in
            var promises = [ Promise<Bool> ]()

            for user: MPUserEntity_CoreData in try context.fetch( MPUserEntity.fetchRequest() ) {
                guard let objectID = (user as? NSManagedObject)?.objectID, !objectID.isTemporaryID
                else {
                    // Not a (saved) object.
                    continue
                }
                guard force || !(self.defaults?.bool( forKey: objectID.uriRepresentation().absoluteString ) ?? false)
                else {
                    // Already imported.
                    continue
                }
                guard let fullName = user.name
                else {
                    // Has no full name.
                    continue
                }
                guard let documentURL = self.url( for: fullName, format: .default )
                else {
                    // Cannot be saved.
                    continue
                }
                try FileManager.default.createDirectory(
                        at: documentURL.deletingLastPathComponent(), withIntermediateDirectories: true )

                var algorithm = MPAlgorithmVersion.current
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
                    throw MPError.internal( details: "Couldn't allocate to marshal \(fullName)" )
                }
                marshalledUser.pointee.redacted = true
                marshalledUser.pointee.avatar = user.avatar_?.uint32Value ?? 0
                marshalledUser.pointee.keyID = UnsafePointer( mpw_strdup( user.keyID?.hexEncodedString() ) )
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
                        throw MPError.internal( details: "Couldn't allocate to marshal \(fullName): \(siteName)" )
                    }
                    marshalledSite.pointee.resultState =
                            UnsafePointer( mpw_strdup( (site as? MPStoredSiteEntity)?.contentObject?.base64EncodedString() ) )
                    marshalledSite.pointee.loginType =
                            (site.loginGenerated_?.boolValue ?? true || site.loginName == nil) ? .templateName: .statefulPersonal
                    marshalledSite.pointee.loginState = UnsafePointer( mpw_strdup( site.loginName ) )
                    marshalledSite.pointee.url = UnsafePointer( mpw_strdup( site.url ?? nil ) )
                    marshalledSite.pointee.uses = site.uses_?.uint32Value ?? 0
                    marshalledSite.pointee.lastUsed = Int( site.lastUsed?.timeIntervalSince1970 ?? 0 )

                    for siteQuestion in site.questions?.seq( MPSiteQuestionEntity_CoreData.self ) ?? [] {
                        guard mpw_marshal_question( marshalledSite, siteQuestion.keyword ) != nil
                        else {
                            throw MPError.internal( details: "Couldn't allocate to marshal \(fullName): \(siteName): \(String( safeUTF8: siteQuestion.keyword ) ?? "-")" )
                        }
                    }
                }

                var file_ptr = mpw_marshal_file( nil, nil, nil )
                defer {
                    mpw_marshal_file_free( &file_ptr )
                }
                guard let file = file_ptr
                else {
                    throw MPError.internal( details: "Couldn't allocate import file." )
                }

                if let data = String( safeUTF8: mpw_marshal_write( .default, file, marshalledUser ),
                                      deallocate: true )?.data( using: .utf8 ),
                   file.pointee.error.type == .success {
                    // TODO: replace by proper promise handling
                    promises.append( self.import( data: data ).then {
                        if (try? $0.get()) ?? false {
                            self.defaults?.set( true, forKey: objectID.uriRepresentation().absoluteString )
                        }
                    } )
                }
                else {
                    throw file.pointee.error
                }
            }

            return Promise<Bool>( reducing: promises, from: true ) { $0 && $1 }
        } ?? Promise( .success( false ) )
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

    private func url(for user: MPUser, in directory: URL? = nil, format: MPMarshalFormat) -> URL? {
        self.url( for: user.fullName, in: directory, format: format )
    }

    private func url(for name: String, in directory: URL? = nil, format: MPMarshalFormat) -> URL? {
        DispatchQueue.mpw.await {
            if let formatExtension = String( safeUTF8: mpw_marshal_format_extension( format ) ),
               let directory = directory ?? self.documentDirectory {
                return directory.appendingPathComponent( name, isDirectory: false )
                                .appendingPathExtension( formatExtension )
            }

            return nil
        }
    }

    // MARK: --- Types ---

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
            let appName    = PearlInfoPlist.get().cfBundleDisplayName ?? productName
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
            self.user.description
        }

        func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
            do {
                // FIXME: possible deadlock if await needs main thread?
                let exportFile = try MPMarshal.shared.save( user: self.user, format: self.format, redacted: self.redacted,
                                                            in: URL( fileURLWithPath: NSTemporaryDirectory() ) ).await()
                self.cleanup.append( exportFile )
                return exportFile
            }
            catch {
                mperror( title: "Issue exporting", context: self.user.fullName, error: error )
                return nil
            }
        }

        func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
            self.format.uti ?? ""
        }

        func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
            "\(PearlInfoPlist.get().cfBundleDisplayName ?? "") Export: \(self.user.fullName)"
        }

        func activityViewController(_ activityViewController: UIActivityViewController, thumbnailImageForActivityType activityType: UIActivity.ActivityType?, suggestedSize size: CGSize) -> UIImage? {
            self.user.avatar.image()
        }

        func activityViewController(_ activityViewController: UIActivityViewController, completed: Bool, forActivityType activityType: UIActivity.ActivityType?, returnedItems: [Any]?, activityError error: Swift.Error?) {
            self.cleanup.removeAll {
                nil != (try? FileManager.default.removeItem( at: $0 ))
            }
        }
    }

    class UserFile: Hashable, Comparable, CustomStringConvertible {
        public let origin: URL?
        public var file:   UnsafeMutablePointer<MPMarshalledFile>

        public let format:     MPMarshalFormat
        public let exportDate: Date
        public let redacted:   Bool

        public let algorithm: MPAlgorithmVersion
        public let avatar:    MPUser.Avatar
        public let fullName:  String
        public let identicon: MPIdenticon
        public let keyID:     String?
        public let lastUsed:  Date

        public let biometricLock: Bool

        public var resetKey = false

        init?(origin: URL?, document: String?) {
            guard let document = document, let file = mpw_marshal_read( nil, document ), file.pointee.error.type == .success
            else { return nil }
            guard let info = file.pointee.info?.pointee, info.format != .none, let fullName = String( safeUTF8: info.fullName )
            else { return nil }

            self.origin = origin
            self.file = file
            self.format = info.format
            self.exportDate = Date( timeIntervalSince1970: TimeInterval( info.exportDate ) )
            self.redacted = info.redacted
            self.algorithm = info.algorithm
            self.avatar = MPUser.Avatar.decode( avatar: info.avatar )
            self.fullName = fullName
            self.identicon = info.identicon
            self.keyID = String( safeUTF8: info.keyID )
            self.lastUsed = Date( timeIntervalSince1970: TimeInterval( info.lastUsed ) )

            self.biometricLock = self.file.mpw_get( path: "user", "_ext_mpw", "biometricLock" ) ?? false
        }

        public func mpw_authenticate(keyFactory: MPKeyFactory) -> Promise<MPUser> {
            DispatchQueue.mpw.promise { () -> MPUser in
                if let marshalledUser = mpw_marshal_auth( self.file, self.resetKey ? nil: keyFactory.provide() )?.pointee,
                   self.file.pointee.error.type == .success {
                    let user = MPUser(
                            algorithm: marshalledUser.algorithm,
                            avatar: MPUser.Avatar.decode( avatar: marshalledUser.avatar ),
                            fullName: String( safeUTF8: marshalledUser.fullName ) ?? self.fullName,
                            identicon: marshalledUser.identicon,
                            masterKeyID: self.resetKey ? nil: self.keyID,
                            masterKeyFactory: keyFactory,
                            defaultType: marshalledUser.defaultType,
                            lastUsed: Date( timeIntervalSince1970: TimeInterval( marshalledUser.lastUsed ) ),
                            origin: self.origin, file: self.file
                    )

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

                    return user
                }

                throw self.file.pointee.error
            }
        }

        // MARK: --- Hashable ---

        func hash(into hasher: inout Hasher) {
            hasher.combine( self.fullName )
        }

        static func ==(lhs: UserFile, rhs: UserFile) -> Bool {
            lhs.fullName == rhs.fullName
        }

        // MARK: --- Comparable ---

        static func <(lhs: UserFile, rhs: UserFile) -> Bool {
            if lhs.lastUsed != rhs.lastUsed {
                return lhs.lastUsed > rhs.lastUsed
            }

            return lhs.fullName > rhs.fullName
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
        "\(self.type.rawValue): \(String( safeUTF8: self.message ) ?? "-")"
    }
}

protocol MPMarshalObserver {
    func userFilesDidChange(_ userFiles: [MPMarshal.UserFile]?)
}
