//
// Created by Maarten Billemont on 2019-05-11.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPMarshal: Observable, Updatable {
    public static let shared = MPMarshal()

    public let observers = Observers<MPMarshalObserver>()
    public var userFiles = [ UserFile ]() {
        didSet {
            self.observers.notify { $0.userFilesDidChange( self.userFiles ) }
        }
    }

    private let marshalQueue      = DispatchQueue( label: "marshal" )
    private let documentDirectory = FileManager.default.containerURL( forSecurityApplicationGroupIdentifier: "group.app.spectre" )
    private lazy var updateTask = DispatchTask( queue: self.marshalQueue, deadline: .now() + .milliseconds( 300 ),
                                                qos: .userInitiated, update: self )

    // MARK: --- Interface ---

    @discardableResult
    public func setNeedsUpdate() -> Promise<Void> {
        self.updateTask.request()
    }

    private func userFile(at documentURL: URL) -> UserFile? {
        guard FileManager.default.fileExists( atPath: documentURL.path ),
              let document = FileManager.default.contents( atPath: documentURL.path )
        else { return nil }

        return self.userFile( for: document, at: documentURL )
    }

    private func userFile(for document: Data, at documentFile: URL? = nil) -> UserFile? {
        UserFile( origin: documentFile, document: String( data: document, encoding: .utf8 ) )
    }

    public func delete(userFile: UserFile) -> Bool {
        guard let userURL = userFile.origin
        else {
            mperror( title: "Couldn't delete user", message: "No origin document for user", details: userFile )
            return false
        }

        do {
            try FileManager.default.removeItem( at: userURL )
            self.userFiles.removeAll { $0 == userFile }
            return true
        }
        catch {
            mperror( title: "Couldn't delete user", message: "Cannot delete origin document", details: userURL.lastPathComponent, error: error )
        }

        return false
    }

    @discardableResult
    public func save(user: MPUser, format: MPMarshalFormat = .default, redacted: Bool = true, in directory: URL? = nil) -> Promise<URL> {
        let saveEvent = MPTracker.shared.begin( named: "marshal #save" )

        return self.marshalQueue.promised {
            guard let documentURL = self.url( for: user, in: directory, format: format )
            else {
                saveEvent.end( [ "result": "!url" ] )
                throw MPError.internal( details: "No path to marshal \(user)" )
            }

            return self.export( user: user, format: format, redacted: redacted ).then { (result: Result<Data, Error>) in
                saveEvent.end( [ "result": result.name ] )

                if !FileManager.default.createFile( atPath: documentURL.path, contents: try result.get() ) {
                    throw MPError.internal( details: "Couldn't save \(documentURL)" )
                }

                self.setNeedsUpdate()
                return documentURL
            }
        }
    }

    public func export(user: MPUser, format: MPMarshalFormat, redacted: Bool) -> Promise<Data> {
        let exportEvent = MPTracker.shared.begin( named: "marshal #export" )

        return DispatchQueue.mpw.promise {
            guard let keyFactory = user.masterKeyFactory
            else {
                exportEvent.end( [ "result": "!keyFactory" ] )
                throw MPError.state( details: "Not authenticated: \(user)." )
            }
            guard let marshalledUser = mpw_marshal_user( user.fullName, keyFactory.provide(), user.algorithm )
            else {
                exportEvent.end( [ "result": "!marshal_user" ] )
                throw MPError.internal( details: "Couldn't allocate for marshalling: \(user)" )
            }

            marshalledUser.pointee.redacted = redacted
            marshalledUser.pointee.avatar = user.avatar.rawValue
            marshalledUser.pointee.identicon = user.identicon
            marshalledUser.pointee.keyID = mpw_strdup( user.masterKeyID )
            marshalledUser.pointee.defaultType = user.defaultType
            marshalledUser.pointee.loginType = user.loginType
            marshalledUser.pointee.loginState = mpw_strdup( user.loginState )
            marshalledUser.pointee.lastUsed = time_t( user.lastUsed.timeIntervalSince1970 )

            for site in user.sites.sorted( by: { $0.siteName < $1.siteName } ) {
                guard let marshalledSite = mpw_marshal_site( marshalledUser, site.siteName, site.resultType, site.counter, site.algorithm )
                else {
                    exportEvent.end( [ "result": "!marshal_site" ] )
                    throw MPError.internal( details: "Couldn't marshal \(user.fullName): \(site)" )
                }

                marshalledSite.pointee.resultState = mpw_strdup( site.resultState )
                marshalledSite.pointee.loginType = site.loginType
                marshalledSite.pointee.loginState = mpw_strdup( site.loginState )
                marshalledSite.pointee.url = mpw_strdup( site.url )
                marshalledSite.pointee.uses = site.uses
                marshalledSite.pointee.lastUsed = time_t( site.lastUsed.timeIntervalSince1970 )

                for question in site.questions.sorted( by: { $0.keyword < $1.keyword } ) {
                    guard let marshalledQuestion = mpw_marshal_question( marshalledSite, question.keyword )
                    else {
                        exportEvent.end( [ "result": "!marshal_question" ] )
                        throw MPError.internal( details: "Couldn't marshal: \(user.fullName): \(site.siteName): \(question)" )
                    }

                    marshalledQuestion.pointee.type = question.resultType
                    marshalledQuestion.pointee.state = mpw_strdup( question.resultState )
                }
            }

            if let data = String.valid( mpw_marshal_write( format, &user.file, marshalledUser ), consume: true )?.data( using: .utf8 ),
               user.file?.pointee.error.type == .success {
                exportEvent.end( [ "result": "success: data" ] )
                return data
            }

            exportEvent.end( [ "result": "!marshal_write" ] )
            throw MPError.marshal( user.file?.pointee.error ?? MPMarshalError( type: .errorInternal, message: nil ), title: "Issue Writing User" )
        }
    }

    @discardableResult
    public func `import`(data: Data) -> Promise<Bool> {
        let importEvent = MPTracker.shared.begin( named: "marshal #importData" )

        return DispatchQueue.mpw.promised {
            guard let importingFile = self.userFile( for: data )
            else {
                mperror( title: "Couldn't import user", message: "Import is no \(productName) document" )
                importEvent.end( [ "result": "!parse" ] )
                return Promise( .success( false ) )
            }
            guard let importingURL = self.url( for: importingFile.fullName, format: importingFile.format )
            else {
                mperror( title: "Couldn't import user", message: "Not a savable document", details: importingFile )
                importEvent.end( [ "result": "!url" ] )
                return Promise( .success( false ) )
            }

            if let existingFile = self.userFile( at: importingURL ) {
                return self.import( data: data, from: importingFile, into: existingFile ).then {
                    importEvent.end( [ "result": $0.name ] )
                }
            }
            else {
                return self.import( data: data, from: importingFile, into: importingURL ).then {
                    importEvent.end( [ "result": $0.name ] )
                }
            }
        }
    }

    private func `import`(data: Data, from importingFile: UserFile, into existingFile: UserFile) -> Promise<Bool> {
        let importEvent = MPTracker.shared.begin( named: "marshal #importIntoFile" )

        return DispatchQueue.main.promised {
            let promise = Promise<Bool>()

            guard let viewController = UIApplication.shared.keyWindow?.rootViewController
            else {
                mperror( title: "Couldn't import user", message: "No window for user interface" )
                importEvent.end( [ "result": "!view" ] )
                return promise.finish( .success( false ) )
            }

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
                importEvent.end( [ "result": "cancel" ] )

                promise.finish( .success( false ) )
            } )
            controller.addAction( UIAlertAction( title: "Replace", style: .destructive ) { _ in
                let replaceEvent = MPTracker.shared.begin( named: "marshal.importIntoFile #replace" )

                guard let authentication = passwordField.authenticate( { keyFactory in
                    importingFile.authenticate( using: keyFactory )
                } )
                else {
                    mperror( title: "Couldn't import user", message: "Missing master password" )
                    replaceEvent.end( [ "result": "!masterPassword" ] )
                    viewController.present( controller, animated: true )
                    return
                }

                spinner.show( dismissAutomatically: false )
                authentication.then( { result in
                    trc( "Import replace authentication: %@", result )
                    spinner.dismiss()

                    switch result {
                        case .success:
                            if let existingURL = existingFile.origin {
                                if FileManager.default.fileExists( atPath: existingURL.path ) {
                                    do { try FileManager.default.removeItem( at: existingURL ) }
                                    catch {
                                        mperror( title: "Migration issue", message: "Cannot delete old user document",
                                                 details: existingURL.lastPathComponent, error: error )
                                    }
                                }

                                self.import( data: data, from: importingFile, into: existingURL ).finishes( promise ).then {
                                    replaceEvent.end( [ "result": $0.name ] )
                                    importEvent.end( [ "result": $0.name ] )
                                }
                            }
                            else {
                                mperror( title: "Migration issue", message: "Replaced user has no document", details: existingFile )
                                replaceEvent.end( [ "result": "!url" ] )
                                importEvent.end( [ "result": "failed" ] )
                                promise.finish( .success( false ) )
                            }

                        case .failure(let error):
                            mperror( title: "Couldn't import user", message: "User authentication failed", error: error )
                            replaceEvent.end( [ "result": "!masterKey" ] )
                            viewController.present( controller, animated: true )
                    }
                } )
            } )
            controller.addAction( UIAlertAction( title: "Merge", style: .default ) { _ in
                let mergeEvent = MPTracker.shared.begin( named: "marshal.importIntoFile #merge" )

                guard let authentication = passwordField.authenticate( { keyFactory in
                    Promise( .success(
                            (try? importingFile.authenticate( using: keyFactory ).await(),
                             try? existingFile.authenticate( using: keyFactory ).await()) ) )
                } )
                else {
                    mperror( title: "Couldn't import user", message: "Missing master password" )
                    mergeEvent.end( [ "result": "!masterPassword" ] )
                    viewController.present( controller, animated: true )
                    return
                }

                spinner.show( dismissAutomatically: false )
                authentication.then( on: .main ) { result in
                    trc( "Import merge authentication: %@", result )
                    spinner.dismiss()

                    do {
                        let (importedUser, existedUser) = try result.get()

                        if let importedUser = importedUser,
                           let existedUser = existedUser {
                            self.import( from: importedUser, into: existedUser ).finishes( promise ).then {
                                mergeEvent.end( [ "result": $0.name ] )
                                importEvent.end( [ "result": $0.name ] )
                            }
                        }
                        else if let importedUser = importedUser {
                            let unlockEvent = MPTracker.shared.begin( named: "marshal.importIntoFile.merge #unlockUser" )

                            let controller = UIAlertController( title: "Unlock Existing User", message:
                            """
                            The existing user is locked with a different master password.

                            The continue merging, also provide the existing user's master password.

                            Replacing will delete the existing user and replace it with the imported user.
                            """, preferredStyle: .alert )

                            let passwordField = MPMasterPasswordField( userFile: existingFile )
                            passwordField.authenticater = { keyFactory in
                                spinner.show( dismissAutomatically: false )
                                return existingFile.authenticate( using: keyFactory )
                            }
                            passwordField.authenticated = { result in
                                trc( "Existing user authentication: %@", result )

                                spinner.dismiss()
                                controller.dismiss( animated: true ) {
                                    do {
                                        self.import( from: importedUser, into: try result.get() ).finishes( promise ).then {
                                            unlockEvent.end( [ "result": $0.name ] )
                                            mergeEvent.end( [ "result": $0.name ] )
                                            importEvent.end( [ "result": $0.name ] )
                                        }
                                    }
                                    catch {
                                        mperror( title: "Couldn't import user", message: "User authentication failed",
                                                 details: existingFile, error: error )
                                        unlockEvent.end( [ "result": "!masterKey" ] )
                                        viewController.present( controller, animated: true )
                                    }
                                }
                            }
                            controller.addTextField { passwordField.passwordField = $0 }
                            controller.addAction( UIAlertAction( title: "Cancel", style: .cancel ) { _ in
                                unlockEvent.end( [ "result": "cancel" ] )
                                mergeEvent.end( [ "result": "failed: cancel" ] )
                                importEvent.end( [ "result": "failed: cancel" ] )
                                promise.finish( .success( false ) )
                            } )
                            controller.addAction( UIAlertAction( title: "Unlock", style: .default ) { _ in
                                if !passwordField.try() {
                                    mperror( title: "Couldn't import user", message: "Missing master password" )
                                    unlockEvent.end( [ "result": "!masterPassword" ] )
                                    viewController.present( controller, animated: true )
                                }
                            } )
                            viewController.present( controller, animated: true )
                        }
                        else if let existedUser = existedUser {
                            let unlockEvent = MPTracker.shared.begin( named: "marshal.importIntoFile.merge #unlockImport" )

                            let controller = UIAlertController( title: "Unlock Import", message:
                            """
                            The import user is locked with a different master password.

                            The continue merging, also provide the imported user's master password.
                            """, preferredStyle: .alert )

                            let passwordField = MPMasterPasswordField( userFile: importingFile )
                            passwordField.authenticater = { keyFactory in
                                spinner.show( dismissAutomatically: false )
                                return importingFile.authenticate( using: keyFactory )
                            }
                            passwordField.authenticated = { result in
                                trc( "Import user authentication: %@", result )

                                spinner.dismiss()
                                controller.dismiss( animated: true ) {
                                    do {
                                        self.import( from: try result.get(), into: existedUser ).finishes( promise ).then {
                                            unlockEvent.end( [ "result": $0.name ] )
                                            mergeEvent.end( [ "result": $0.name ] )
                                            importEvent.end( [ "result": $0.name ] )
                                        }
                                    }
                                    catch {
                                        mperror( title: "Couldn't import user", message: "User authentication failed",
                                                 details: importingFile, error: error )
                                        unlockEvent.end( [ "result": "!masterKey" ] )
                                        viewController.present( controller, animated: true )
                                    }
                                }
                            }
                            controller.addTextField { passwordField.passwordField = $0 }
                            controller.addAction( UIAlertAction( title: "Cancel", style: .cancel ) { _ in
                                unlockEvent.end( [ "result": "cancel" ] )
                                mergeEvent.end( [ "result": "failed: cancel" ] )
                                importEvent.end( [ "result": "failed: cancel" ] )
                                promise.finish( .success( false ) )
                            } )
                            controller.addAction( UIAlertAction( title: "Unlock", style: .default ) { _ in
                                if !passwordField.try() {
                                    mperror( title: "Couldn't import user", message: "Missing master password" )
                                    unlockEvent.end( [ "result": "!masterPassword" ] )
                                    viewController.present( controller, animated: true )
                                }
                            } )
                            viewController.present( controller, animated: true )
                        }
                        else {
                            mperror( title: "Couldn't import user", message: "User authentication failed" )
                            mergeEvent.end( [ "result": "!masterKey" ] )
                            viewController.present( controller, animated: true )
                        }
                    }
                    catch {
                        mperror( title: "Couldn't import user", error: error )
                        mergeEvent.end( [ "result": "unexpected" ] )
                        viewController.present( controller, animated: true )
                    }
                }
            } )

            viewController.present( controller, animated: true )
            return promise
        }
    }

    private func `import`(from importedUser: MPUser, into existedUser: MPUser) -> Promise<Bool> {
        let importEvent = MPTracker.shared.begin( named: "marshal #importIntoUser" )

        let spinner = MPAlert( title: "Merging", message: existedUser.description,
                               content: UIActivityIndicatorView( style: .whiteLarge ) )

        spinner.show( dismissAutomatically: false )

        return DispatchQueue.mpw.promised {
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

                existedUser.sites.append( importedSite.copy( to: existedUser ) )
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

            return DispatchQueue.main.promise {
                spinner.dismiss()

                if !updatedUser && replacedSites + newSites == 0 {
                    importEvent.end( [ "result": "success: skipped" ] )
                    MPAlert( title: "Import Skipped", message: existedUser.description, details:
                    """
                    The import into \(existedUser) was skipped.

                    This merge import contained no information that was either new or missing for the existing user.
                    """ ).show()
                }
                else {
                    importEvent.end( [ "result": "success: complete" ] )
                    MPAlert( title: "Import Complete", message: existedUser.description, details:
                    """
                    Completed the import of sites into \(existedUser).

                    This was a merge import.  \(replacedSites) sites were replaced, \(newSites) new sites were created.
                    \(updatedUser ?
                            "The user settings were updated from the import.":
                            "The existing user's settings were more recent than the import.")
                    """ ).show()
                }

                self.setNeedsUpdate()
                return true
            }
        }
    }

    private func `import`(data: Data, from importingFile: UserFile, into documentURL: URL) -> Promise<Bool> {
        let importEvent = MPTracker.shared.begin( named: "marshal #importIntoURL" )

        let spinner = MPAlert( title: "Replacing", message: documentURL.lastPathComponent,
                               content: UIActivityIndicatorView( style: .whiteLarge ) )

        spinner.show( dismissAutomatically: false )

        return DispatchQueue.mpw.promise {
            FileManager.default.createFile( atPath: documentURL.path, contents: data )
        }.then {
            spinner.dismiss()

            do {
                if try $0.get() {
                    importEvent.end( [ "result": "success: complete" ] )
                    MPAlert( title: "Import Complete", message: documentURL.lastPathComponent, details:
                    """
                    Completed the import of \(importingFile) (\(importingFile.format)).
                    This export file was created on \(importingFile.exportDate).

                    This was a direct installation of the import data, not a merge import.
                    """ ).show()
                    self.setNeedsUpdate()
                }
                else {
                    mperror( title: "Couldn't import user", message: "Couldn't save user document", details: documentURL )
                    importEvent.end( [ "result": "!createFile" ] )
                }
            }
            catch {
                mperror( title: "Couldn't import user", message: "Couldn't save user document", details: documentURL, error: error )
                importEvent.end( [ "result": $0.name ] )
            }
        }
    }

    private func userDocuments() -> [URL] {
        guard let documentsDirectory = self.documentDirectory
        else { return [] }

        do {
            return try FileManager.default.contentsOfDirectory( atPath: documentsDirectory.path ).compactMap {
                documentsDirectory.appendingPathComponent( $0 )
            }
        }
        catch {
            mperror( title: "Couldn't list user documents", error: error )
            return []
        }
    }

    private func url(for user: MPUser, in directory: URL? = nil, format: MPMarshalFormat) -> URL? {
        self.url( for: user.fullName, in: directory, format: format )
    }

    private func url(for name: String, in directory: URL? = nil, format: MPMarshalFormat) -> URL? {
        DispatchQueue.mpw.await {
            if let formatExtension = String.valid( mpw_format_extension( format ) ),
               let directory = directory ?? self.documentDirectory {
                return directory.appendingPathComponent( name, isDirectory: false )
                                .appendingPathExtension( formatExtension )
            }

            return nil
        }
    }

    // MARK: --- Updatable ---

    func update() {
        self.userFiles = self.userDocuments().compactMap { self.userFile( at: $0 ) }
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
            if self.redacted {
                return """
                       \(productName) export file (\(self.format)) for \(self.user)
                       NOTE: This is a SECURE export; access to the file does not expose its secrets.
                       ---
                       \(productName) v\(productVersion) (\(productBuild))
                       """
            }
            else {
                return """
                       \(productName) export (\(self.format)) for \(self.user)
                       NOTE: This export file's passwords are REVEALED.  Keep it safe!
                       ---
                       \(productName) v\(productVersion) (\(productBuild))
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
                mperror( title: "Couldn't export user document", details: self.user, error: error )
                return nil
            }
        }

        func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
            self.format.uti ?? ""
        }

        func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
            "\(productName) Export: \(self.user.fullName)"
        }

        func activityViewController(_ activityViewController: UIActivityViewController, thumbnailImageForActivityType activityType: UIActivity.ActivityType?, suggestedSize size: CGSize) -> UIImage? {
            self.user.avatar.image
        }

        func activityViewController(_ activityViewController: UIActivityViewController, completed: Bool, forActivityType activityType: UIActivity.ActivityType?, returnedItems: [Any]?, activityError error: Swift.Error?) {
            self.cleanup.removeAll {
                nil != (try? FileManager.default.removeItem( at: $0 ))
            }
        }
    }

    class UserFile: Hashable, Comparable, CustomStringConvertible {
        public lazy var keychainKeyFactory = MPKeychainKeyFactory( fullName: self.fullName )

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
            guard let info = file.pointee.info?.pointee, info.format != .none, let fullName = String.valid( info.fullName )
            else { return nil }

            self.origin = origin
            self.file = file
            self.format = info.format
            self.exportDate = Date( timeIntervalSince1970: TimeInterval( info.exportDate ) )
            self.redacted = info.redacted
            self.algorithm = info.algorithm
            self.avatar = MPUser.Avatar( rawValue: info.avatar ) ?? .avatar_0
            self.fullName = fullName
            self.identicon = info.identicon
            self.keyID = .valid( info.keyID )
            self.lastUsed = Date( timeIntervalSince1970: TimeInterval( info.lastUsed ) )

            self.biometricLock = self.file.mpw_get( path: "user", "_ext_mpw", "biometricLock" ) ?? false
        }

        public func authenticate(using keyFactory: MPKeyFactory) -> Promise<MPUser> {
            DispatchQueue.mpw.promised {
                if let marshalledUser = mpw_marshal_auth( self.file, self.resetKey ? nil: keyFactory.provide() )?.pointee,
                   self.file.pointee.error.type == .success {
                    return MPUser(
                            algorithm: marshalledUser.algorithm,
                            avatar: MPUser.Avatar( rawValue: marshalledUser.avatar ) ?? .avatar_0,
                            fullName: String.valid( marshalledUser.fullName ) ?? self.fullName,
                            identicon: marshalledUser.identicon,
                            masterKeyID: self.resetKey ? nil: self.keyID,
                            defaultType: marshalledUser.defaultType,
                            loginType: marshalledUser.loginType,
                            loginState: .valid( marshalledUser.loginState ),
                            lastUsed: Date( timeIntervalSince1970: TimeInterval( marshalledUser.lastUsed ) ),
                            origin: self.origin, file: self.file
                    ) { user in

                        for s in 0..<marshalledUser.sites_count {
                            let marshalledSite = (marshalledUser.sites + s).pointee
                            if let siteName = String.valid( marshalledSite.siteName ) {
                                user.sites.append( MPSite(
                                        user: user,
                                        siteName: siteName,
                                        algorithm: marshalledSite.algorithm,
                                        counter: marshalledSite.counter,
                                        resultType: marshalledSite.resultType,
                                        resultState: .valid( marshalledSite.resultState ),
                                        loginType: marshalledSite.loginType,
                                        loginState: .valid( marshalledSite.loginState ),
                                        url: .valid( marshalledSite.url ),
                                        uses: marshalledSite.uses,
                                        lastUsed: Date( timeIntervalSince1970: TimeInterval( marshalledSite.lastUsed ) )
                                ) { site in

                                    for q in 0..<marshalledSite.questions_count {
                                        let marshalledQuestion = (marshalledSite.questions + q).pointee
                                        if let keyword = String.valid( marshalledQuestion.keyword ) {
                                            site.questions.append( MPQuestion(
                                                    site: site,
                                                    keyword: keyword,
                                                    resultType: marshalledQuestion.type,
                                                    resultState: .valid( marshalledQuestion.state )
                                            ) )
                                        }
                                    }
                                } )
                            }
                        }
                    }.login( using: keyFactory )
                }

                throw MPError.marshal( self.file.pointee.error, title: "Issue Authenticating User" )
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
                    return "\(self.fullName): \(identicon) [\(self.format)]"
                }
                else if let keyID = self.keyID {
                    return "\(self.fullName): \(keyID) [\(self.format)]"
                }
                else {
                    return "\(self.fullName) [\(self.format)]"
                }
            }
        }
    }
}

extension MPMarshalError: LocalizedError {
    public var errorDescription: String? {
        .valid( self.message )
    }

    public var failureReason: String? {
        switch self.type {
            case .success:
                return "The marshalling operation completed successfully. (\(self.type))"
            case .errorStructure:
                return "An error in the structure of the marshall file interrupted marshalling. (\(self.type))"
            case .errorFormat:
                return "The marshall file uses an unsupported format version. (\(self.type))"
            case .errorMissing:
                return "A required value is missing or not specified. (\(self.type))"
            case .errorMasterPassword:
                return "The given master password is not valid. (\(self.type))"
            case .errorIllegal:
                return "An illegal value was specified. (\(self.type))"
            case .errorInternal:
                return "An internal system error interrupted marshalling. (\(self.type))"
            @unknown default:
                return "MPMarshalError (\(self.type))"
        }
    }
}

protocol MPMarshalObserver {
    func userFilesDidChange(_ userFiles: [MPMarshal.UserFile])
}
