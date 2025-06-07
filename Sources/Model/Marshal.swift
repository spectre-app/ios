//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import Foundation

// swiftlint:disable:next type_body_length
actor Marshal: Observed, LeakObserver {
    public static let shared = Marshal()

    public nonisolated let observers = Observers<MarshalObserver>()

    public lazy var userFiles: [UserFile] = self.loadUserFiles() {
        didSet {
            self.observers.notify { $0.didChange(userFiles: self.userFiles) }

            Task.detached { await AutoFill.shared.seed(self.userFiles) }
        }
    }

    // MARK: - Life

    private var userFilesMonitor: DispatchSourceProtocol? {
        didSet {
            oldValue?.cancel()
            self.userFilesMonitor?.setEventHandler(qos: .utility, handler: .init { [weak self] in
                Task { [weak self] in await self?.updateUserFiles() }
            })
            self.userFilesMonitor?.activate()
        }
    }

    private init() {
        LeakRegistry.shared.observers.register(observer: self)
        self.observers.registration = { [unowned self] observer in
            Task { await observer.didChange(userFiles: self.userFiles) }
        }
    }

    // MARK: - Interface

    public func delete(userFile: UserFile) throws {
        guard let userURL = userFile.origin
        else { throw AppError.issue("No user document", reason: userFile) }

        do {
            try FileManager.default.removeItem(at: userURL)
            self.userFiles.removeAll { $0 == userFile }
        }
        catch {
            throw AppError.issue("Cannot delete user document", reason: userURL.lastPathComponent, cause: error)
        }
    }

    public func save(user: User) async throws -> URL {
        let redacted = user.file?.pointee.info?.pointee.redacted ?? true
        let format = user.file.flatMap { $0.pointee.info?.pointee.format ?? .default } ?? .none
        guard let userURL = user.origin.flatMap({ format.is(url: $0) ? $0 : nil }) ?? self.createURL(for: user, format: format)
        else { throw AppError.internal(reason: "No path to marshal user", details: user) }

        return try await self.save(user: user, to: userURL, format: format, redacted: redacted)
    }

    private func save(user: User, in directory: URL?, format: SpectreFormat, redacted: Bool) async throws -> URL {
        guard let userURL = self.createURL(for: user, in: directory, format: format)
        else { throw AppError.internal(reason: "No path to marshal user", details: user) }

        return try await self.save(user: user, to: userURL, format: format, redacted: redacted)
    }

    private func save(user: User, to userURL: URL, format: SpectreFormat, redacted: Bool) async throws -> URL {
        let saveEvent = Tracker.shared.begin(track: .subject("user", action: "save"))

        do {
            guard !userURL.hasDirectoryPath
            else {
                saveEvent.end(["result": "!dir"])
                throw AppError.internal(reason: "Cannot save to a directory URL", details: userURL)
            }

            do {
                let documentDirectory = userURL.deletingLastPathComponent()
                if documentDirectory.hasDirectoryPath {
                    try FileManager.default.createDirectory(at: documentDirectory, withIntermediateDirectories: true)
                }
            }
            catch {
                saveEvent.end(["result": "!path"])
                throw AppError.issue("Cannot create document path", reason: userURL, cause: error)
            }

            let exportData = try await self.export(user: user, format: format, redacted: redacted)

            // Save export data to user's origin.
            var coordinateError: NSError?, saveError: Error?
            NSFileCoordinator().coordinate(writingItemAt: userURL, error: &coordinateError) { userURL in
                let securityScoped = userURL.startAccessingSecurityScopedResource()
                if !FileManager.default.createFile(atPath: userURL.path, contents: exportData) {
                    saveError = AppError.internal(reason: "Couldn't create file", details: userURL)
                }
                if securityScoped {
                    userURL.stopAccessingSecurityScopedResource()
                }
            }
            if let error = coordinateError.flatMap({ AppError.issue("Couldn't access file", cause: $0) }) ?? saveError {
                throw error
            }

            // If user sharing is enabled, share the export through the app's public documents as well.
            if user.sharing {
                if let sharingURL = self.createURL(for: user, in: FileManager.appDocuments, format: format) {
                    if !FileManager.default.createFile(atPath: sharingURL.path, contents: exportData) {
                        wrn("Issue sharing user: Couldn't create user file.", data: sharingURL)
                    }
                }
                else {
                    wrn("Issue sharing user: No application document path available.")
                }
            }
            saveEvent.end(["result": "success"])

            self.updateUserFiles()
            return userURL
        }
        catch {
            saveEvent.end(["result": "failure", "error": error])
            throw error
        }
    }

    public func export(user: User, format: SpectreFormat, redacted: Bool) async throws -> Data {
        let exportEvent = Tracker.shared.begin(track: .subject("user", action: "export"))

        guard let keyFactory = user.userKeyFactory
        else {
            exportEvent.end(["result": "!keyFactory"])
            throw AppError.issue("Not authenticated", reason: user)
        }

        let keyProvider = keyFactory.provide()
        guard let marshalledUser = spectre_marshal_user(user.userName, keyProvider, user.algorithm)
        else {
            exportEvent.end(["result": "!marshal_user"])
            throw AppError.internal(reason: "Couldn't marshal user", details: user)
        }

        marshalledUser.pointee.redacted = redacted
        marshalledUser.pointee.avatar = user.avatar.rawValue
        marshalledUser.pointee.identicon = user.identicon
        marshalledUser.pointee.keyID = user.userKeyID
        marshalledUser.pointee.resultType = user.resultType
        marshalledUser.pointee.loginType = user.loginType
        marshalledUser.pointee.loginState = spectre_strdup(user.loginState)
        marshalledUser.pointee.lastUsed = time_t(user.lastUsed.timeIntervalSince1970)

        for site in user.sites.sorted(by: { $0.siteName < $1.siteName }) {
            guard let marshalledSite = spectre_marshal_site(marshalledUser, site.siteName, site.resultType, site.counter, site.algorithm)
            else {
                exportEvent.end(["result": "!marshal_site"])
                throw AppError.internal(reason: "Couldn't marshal site", details: [user, site] as [Any])
            }

            marshalledSite.pointee.resultState = spectre_strdup(site.resultState)
            marshalledSite.pointee.loginType = site.loginType
            marshalledSite.pointee.loginState = spectre_strdup(site.loginState)
            marshalledSite.pointee.url = spectre_strdup(site.url.nonEmpty)
            marshalledSite.pointee.domains = spectre_strdup(site.domains.joined(separator: ",").nonEmpty)
            marshalledSite.pointee.uses = site.uses
            marshalledSite.pointee.lastUsed = time_t(site.lastUsed.timeIntervalSince1970)

            for question in site.questions.sorted(by: { $0.keyword < $1.keyword }) {
                guard let marshalledQuestion = spectre_marshal_question(marshalledSite, question.keyword)
                else {
                    exportEvent.end(["result": "!marshal_question"])
                    throw AppError.internal(reason: "Couldn't marshal question", details: [user, site, question] as [Any])
                }

                marshalledQuestion.pointee.type = question.resultType
                marshalledQuestion.pointee.state = spectre_strdup(question.resultState)
            }
        }

        guard let data = String.valid(spectre_marshal_write(format, &user.file, marshalledUser), consume: true)?.data(using: .utf8),
              user.file?.pointee.error.type == .success
        else {
            exportEvent.end(["result": "!marshal_write"])
            throw AppError.marshal(
                user.file?.pointee.error ?? SpectreMarshalError(type: .errorInternal, message: nil),
                title: "Issue writing user", details: user
            )
        }

        exportEvent.end(["result": "success"])
        return data
    }

    public func `import`(
        data importingData: Data, merge: Bool,
        needAuthentication: (UserFile, Error?) async throws -> KeyFactory,
        didMerge: (User, User, (userDetails: Bool, addedSites: Int, replacedSites: Int)) -> Void
    ) async throws {
        let importEvent = Tracker.shared.begin(track: .subject("import", action: "to-file"))

        let importingFile = try UserFile(data: importingData)
        guard let destinationURL = self.createURL(for: importingFile.userName, format: importingFile.format)
        else {
            importEvent.end(["result": "!url"])
            throw AppError.issue("User not savable", reason: importingFile)
        }

        guard let existingFile = try UserFile(origin: destinationURL)
        else {
            try await self.import(data: importingData, from: importingFile, into: destinationURL)
            importEvent.end(["result": "success"])
            return
        }

        if !merge {
            let replaceEvent = Tracker.shared.begin(track: .subject("import.to-file", action: "replace"))
            if let existingURL = existingFile.origin {
                do {
                    if FileManager.default.fileExists(atPath: existingURL.path) {
                        trc("Import replace authentication")
                        var previousError: Error?
                        repeat {
                            let keyFactory = try await needAuthentication(existingFile, previousError)

                            do {
                                _ = try await existingFile.authenticate(using: keyFactory)
                                break
                            }
                            catch {
                                err("User could not be unlocked.", data: error)
                                previousError = error
                            }
                        }
                        while true

                        do {
                            try FileManager.default.removeItem(at: existingURL)
                        }
                        catch {
                            wrn("Couldn't delete existing document when importing new one.", data: existingURL, error)
                        }
                    }

                    try await self.import(data: importingData, from: importingFile, into: existingURL)
                    replaceEvent.end(["result": "success"])
                    importEvent.end(["result": "success"])
                }
                catch {
                    replaceEvent.end(["result": "failure", "error": error])
                    importEvent.end(["result": "failure", "error": error])
                    throw error
                }
            }
            else {
                replaceEvent.end(["result": "!existingURL"])
                importEvent.end(["result": "!existingURL"])
                throw AppError.internal(reason: "Target user has no document", details: existingFile)
            }
        }
        else {
            let mergeEvent = Tracker.shared.begin(track: .subject("import.to-file", action: "merge"))

            trc("Import merge authentication")
            let (importingUser, existingUser) = try await {
                var previousError: Error?
                repeat {
                    let keyFactory = try await needAuthentication(importingFile, previousError)

                    do {
                        return try await (
                            importingFile.authenticate(using: keyFactory),
                            existingFile.authenticate(using: keyFactory)
                        )
                    }
                    catch {
                        err("User could not be unlocked.", data: error)
                        previousError = error
                    }
                }
                while true
            }()

            try await didMerge(
                importingUser, existingUser,
                self.import(from: importingUser, into: existingUser)
            )
            mergeEvent.end(["result": "success"])
            importEvent.end(["result": "success"])
        }
    }

    // MARK: - Private

    private func `import`(from importedUser: User, into existingUser: User) async throws
        -> (userDetails: Bool, addedSites: Int, replacedSites: Int) {
        let importEvent = Tracker.shared.begin(track: .subject("import", action: "to-user"))

        var replacedSites = 0, addedSites = 0
        for importedSite in importedUser.sites {
            if let existedSite = existingUser.sites.first(where: { $0.siteName == importedSite.siteName }) {
                // TODO: Merge questions.
                if importedSite.lastUsed < existedSite.lastUsed || importedSite == existedSite {
                    continue
                }

                existingUser.sites.removeAll { $0 === existedSite }
                replacedSites += 1
            }
            else {
                addedSites += 1
            }

            existingUser.sites.append(importedSite.copy(to: existingUser))
        }

        var userDetails = false
        if importedUser.lastUsed >= existingUser.lastUsed {
            existingUser.algorithm = importedUser.algorithm
            existingUser.avatar = importedUser.avatar
            existingUser.identicon = importedUser.identicon
            existingUser.userKeyID = importedUser.userKeyID
            existingUser.resultType = importedUser.resultType
            existingUser.loginType = importedUser.loginType
            existingUser.loginState = importedUser.loginState
            existingUser.lastUsed = importedUser.lastUsed
            existingUser.maskPasswords = importedUser.maskPasswords
            existingUser.biometricLock = importedUser.biometricLock
            existingUser.autofill = importedUser.autofill
            existingUser.attacker = importedUser.attacker
            userDetails = true
        }

        if !userDetails, replacedSites + addedSites == 0 {
            importEvent.end(["result": "success", "type": "skipped"])
        }
        else {
            importEvent.end(["result": "success", "type": "merged"])
        }

        self.updateUserFiles()
        return (userDetails: userDetails, addedSites: addedSites, replacedSites: replacedSites)
    }

    @MainActor
    private func `import`(data: Data, from importingFile: UserFile, into documentURL: URL) async throws {
        let importEvent = Tracker.shared.begin(track: .subject("import", action: "to-url"))

        guard !documentURL.hasDirectoryPath
        else { throw AppError.internal(reason: "Cannot save to a directory URL", details: documentURL) }
        do {
            let documentDirectory = documentURL.deletingLastPathComponent()
            if documentDirectory.hasDirectoryPath {
                try FileManager.default.createDirectory(
                    at: documentURL.deletingLastPathComponent(), withIntermediateDirectories: true
                )
            }
        }
        catch {
            importEvent.end(["result": "!createPath"])
            throw AppError.issue("Cannot create document path", reason: documentURL, cause: error)
        }

        if !FileManager.default.createFile(atPath: documentURL.path, contents: data) {
            importEvent.end(["result": "!createFile"])
            throw AppError.issue("Cannot write user document", reason: documentURL)
        }
        importingFile.origin = documentURL

        importEvent.end(["result": "success", "type": "created"])

        await self.updateUserFiles()
    }

//    #if TARGET_APP
//    public func `import`(data: Data, viewController: UIViewController) async throws -> UserFile {
//        let importEvent = Tracker.shared.begin( track: .subject( "import", action: "from-data" ) )
//
//        do {
//            let importingFile = try UserFile( data: data )
//            guard let importingURL = self.createURL( for: importingFile.userName, format: importingFile.format )
//            else {
//                importEvent.end( [ "result": "!url" ] )
//                throw AppError.issue( title: "User not savable", details: importingFile )
//            }
//
//            let importedFile: UserFile
//            if let existingFile = try UserFile( origin: importingURL ) {
//                importedFile = try await self.import( data: data, from: importingFile, into: existingFile, viewController: viewController )
//            }
//            else {
//                importedFile = try await self.import( data: data, from: importingFile, into: importingURL, viewController: viewController )
//            }
//
//            // Master Password purchase migration
//            if AppConfig.shared.masterPasswordCustomer, !StoreSubscription.premium.isEnabled {
//                await viewController.present( DialogMasterPasswordViewController(), animated: true )
//            }
//
//            importEvent.end( [ "result": "success" ] )
//            return importedFile
//        }
//        catch {
//            importEvent.end( [ "result": "failure" ] )
//            throw error
//        }
//    }
//    #endif
//
//    // MARK: - Private
//
//    @MainActor
//    private func `import`(data: Data, from importingFile: UserFile, into existingFile: UserFile, viewController: UIViewController) async throws
//            -> UserFile {
//        let importEvent = Tracker.shared.begin( track: .subject( "import", action: "to-file" ) )
//
//        return try await withCheckedThrowingContinuation { continuation in
//            let spinner         = AlertController( title: "Unlocking", message: importingFile.description,
//                                                   content: UIActivityIndicatorView( style: .large ) )
//            let secretField     = UserSecretField<User>( userName: existingFile.userName, identicon: existingFile.identicon )
//            let alertController = UIAlertController( title: "Merge Users", message:
//            """
//            \(existingFile.userName) already exists.
//
//            Replacing will delete the existing user and replace it with the imported user.
//
//            Merging will import only the new information from the import file into the existing user.
//            """, preferredStyle: .alert )
//            alertController.addTextField { secretField.passwordField = $0 }
//            alertController.addAction( UIAlertAction( title: "Cancel", style: .cancel ) { _ in
//                importEvent.end( [ "result": "cancelled" ] )
//                continuation.resume( throwing: CancellationError() )
//            } )
//            alertController.addAction( UIAlertAction( title: "Replace", style: .destructive ) { _ in
//                let replaceEvent = Tracker.shared.begin( track: .subject( "import.to-file", action: "replace" ) )
//
//                guard let authentication = secretField.authenticate( { keyFactory in
//                    try await importingFile.authenticate( using: keyFactory )
//                } )
//                else {
//                    mperror( title: "Couldn't import user", message: "Authentication information cannot be left empty.",
//                             in: viewController.view )
//                    replaceEvent.end( [ "result": "!userSecret" ] )
//                    viewController.present( alertController, animated: true )
//                    return
//                }
//
//                Task {
//                    trc( "Import replace authentication" )
//                    spinner.show( in: viewController.view, dismissAutomatically: false )
//
//                    do {
//                        _ = try await authentication.value
//                        spinner.dismiss()
//
//                        if let existingURL = existingFile.origin {
//                            if FileManager.default.fileExists( atPath: existingURL.path ) {
//                                do { try FileManager.default.removeItem( at: existingURL ) }
//                                catch {
//                                    wrn( "Couldn't delete existing document when importing new one: %@ [>PII]", error.localizedDescription )
//                                    pii( "[>] URL: %@, Error: %@", existingURL, error )
//                                }
//                            }
//
//                            do {
//                                continuation.resume( returning: try await self.import(
//                                        data: data, from: importingFile, into: existingURL, viewController: viewController
//                                ) )
//                                replaceEvent.end( [ "result": "success" ] )
//                                importEvent.end( [ "result": "success" ] )
//                            } catch {
//                                replaceEvent.end( [ "result": "failure", "error": error ] )
//                                importEvent.end( [ "result": "failure", "error": error ] )
//                                continuation.resume( throwing: error )
//                            }
//                        }
//                        else {
//                            replaceEvent.end( [ "result": "!existingURL" ] )
//                            importEvent.end( [ "result": "!existingURL" ] )
//                            continuation.resume( throwing: AppError.internal( reason: "Target user has no document", details: existingFile ) )
//                        }
//                    }
//                    catch {
//                        spinner.dismiss()
//                        mperror( title: "Couldn't import user", message: "User could not be unlocked.",
//                                 error: error, in: viewController.view )
//                        replaceEvent.end( [ "result": "!userKey" ] )
//                        viewController.present( alertController, animated: true )
//                    }
//                }
//            } )
//            alertController.addAction( UIAlertAction( title: "Merge", style: .default ) { _ in
//                Task {
//                    let mergeEvent = Tracker.shared.begin( track: .subject( "import.to-file", action: "merge" ) )
//
//                    guard let authentication = secretField.authenticate( { keyFactory in
//                        await (try? importingFile.authenticate( using: keyFactory ), try? existingFile.authenticate( using: keyFactory ))
//                    } )
//                    else {
//                        mperror( title: "Couldn't import user", message: "Authentication information cannot be left empty.",
//                                 in: viewController.view )
//                        mergeEvent.end( [ "result": "!userSecret" ] )
//                        viewController.present( alertController, animated: true )
//                        return
//                    }
//
//                    trc( "Import merge authentication" )
//                    spinner.show( in: viewController.view, dismissAutomatically: false )
//
//                    do {
//                        let (importedUser, existedUser) = try await authentication.value
//                        spinner.dismiss()
//
//                        if let importedUser = importedUser, let existedUser = existedUser {
//                            _ = await self.import( from: importedUser, into: existedUser, viewController: viewController )
//                            mergeEvent.end( [ "result": "success" ] )
//                            importEvent.end( [ "result": "success" ] )
//                            continuation.resume( returning: existingFile )
//                        }
//                        else if let importedUser = importedUser {
//                            let existingUser = try await UIAlertController.authenticate(
//                                    userFile: existingFile, title: "Unlock Existing User", message:
//                            """
//                            The existing user is locked with a different personal secret.
//
//                            To continue merging, also provide the existing user's personal secret.
//
//                            Replacing will delete the existing user and replace it with the imported user.
//                            """, action: "Unlock", in: viewController,
//                                    track: .subject( "import.to-file.merge", action: "unlockUser" ) )
//                            _ = await self.import( from: importedUser, into: existingUser, viewController: viewController )
//                            mergeEvent.end( [ "result": "success" ] )
//                            importEvent.end( [ "result": "success" ] )
//                            continuation.resume( returning: existingFile )
//                        }
//                        else if let existedUser = existedUser {
//                            let importingUser = try await UIAlertController.authenticate(
//                                    userFile: importingFile, title: "Unlock Import", message:
//                            """
//                            The import user is locked with a different personal secret.
//
//                            The continue merging, also provide the imported user's personal secret.
//                            """, action: "Unlock", in: viewController,
//                                    track: .subject( "import.to-file.merge", action: "unlockImport" ) )
//                            _ = await self.import( from: importingUser, into: existedUser, viewController: viewController )
//                            mergeEvent.end( [ "result": "success" ] )
//                            importEvent.end( [ "result": "success" ] )
//                            continuation.resume( returning: existingFile )
//                        }
//                        else {
//                            mperror( title: "Couldn't import user", message: "Couldn't unlock the user.", in: viewController.view )
//                            mergeEvent.end( [ "result": "!userKey" ] )
//                            viewController.present( alertController, animated: true )
//                        }
//                    }
//                    catch {
//                        spinner.dismiss()
//                        mergeEvent.end( [ "result": "failed", "error": error ] )
//                        importEvent.end( [ "result": "failed", "error": error ] )
//                        continuation.resume( throwing: AppError.internal( reason: "No known path for promise to fail" ) )
//                    }
//                }
//            } )
//
//            viewController.present( alertController, animated: true )
//        }
//    }
//
//    private func `import`(from importedUser: User, into existedUser: User, viewController: UIViewController) async
//            -> User {
//        let importEvent = Tracker.shared.begin( track: .subject( "import", action: "to-user" ) )
//
//        let spinner = await AlertController( title: "Merging", message: existedUser.description,
//                                             content: UIActivityIndicatorView( style: .large ) )
//        await spinner.show( in: viewController.view, dismissAutomatically: false )
//
//        var replacedSites = 0, addedSites = 0
//        for importedSite in importedUser.sites {
//            if let existedSite = existedUser.sites.first( where: { $0.siteName == importedSite.siteName } ) {
//                if importedSite.lastUsed <= existedSite.lastUsed {
//                    continue
//                }
//
//                existedUser.sites.removeAll { $0 === existedSite }
//                replacedSites += 1
//            }
//            else {
//                addedSites += 1
//            }
//
//            existedUser.sites.append( importedSite.copy( to: existedUser ) )
//        }
//
//        var updatedUser = false
//        if importedUser.lastUsed >= existedUser.lastUsed {
//            existedUser.algorithm = importedUser.algorithm
//            existedUser.avatar = importedUser.avatar
//            existedUser.identicon = importedUser.identicon
//            existedUser.userKeyID = importedUser.userKeyID
//            existedUser.resultType = importedUser.resultType
//            existedUser.loginType = importedUser.loginType
//            existedUser.loginState = importedUser.loginState
//            existedUser.lastUsed = importedUser.lastUsed
//            existedUser.maskPasswords = importedUser.maskPasswords
//            existedUser.biometricLock = importedUser.biometricLock
//            existedUser.autofill = importedUser.autofill
//            existedUser.attacker = importedUser.attacker
//            updatedUser = true
//        }
//
//        await spinner.dismiss()
//
//        if !updatedUser && replacedSites + addedSites == 0 {
//            importEvent.end( [ "result": "success", "type": "skipped" ] )
//            await AlertController( title: "Import Skipped", message: existedUser.description, details:
//            """
//            The import into \(existedUser) was skipped.
//
//            This merge import contained no information that was either new or missing for the existing user.
//            """ ).show( in: viewController.view )
//        }
//        else {
//            importEvent.end( [ "result": "success", "type": "merged" ] )
//            await AlertController( title: "Import Complete", message: existedUser.description, details:
//            """
//            Completed the import of sites into \(existedUser).
//
//            This was a merge import.  \(replacedSites) sites were replaced, \(addedSites) new sites were created.
//            \(updatedUser ? "The user settings were updated from the import."
//                          : "The existing user's settings were more recent than the import.")
//            """ ).show( in: viewController.view )
//        }
//
//        self.updateUserFiles()
//        return existedUser
//    }
//
//    @MainActor
//    private func `import`(data: Data, from importingFile: UserFile, into documentURL: URL, viewController: UIViewController) async throws
//            -> UserFile {
//        let importEvent = Tracker.shared.begin( track: .subject( "import", action: "to-url" ) )
//
//        let spinner = AlertController( title: "Replacing", message: documentURL.lastPathComponent,
//                                             content: UIActivityIndicatorView( style: .large ) )
//        spinner.show( in: viewController.view, dismissAutomatically: false )
//        defer { spinner.dismiss() }
//
//        guard !documentURL.hasDirectoryPath
//        else { throw AppError.internal( reason: "Cannot save to a directory URL", details: documentURL ) }
//        do {
//            let documentDirectory = documentURL.deletingLastPathComponent()
//            if documentDirectory.hasDirectoryPath {
//                try FileManager.default.createDirectory(
//                        at: documentURL.deletingLastPathComponent(), withIntermediateDirectories: true )
//            }
//        }
//        catch {
//            importEvent.end( [ "result": "!createPath" ] )
//            throw AppError.issue( error, title: "Cannot create document path", details: documentURL )
//        }
//
//        if !FileManager.default.createFile( atPath: documentURL.path, contents: data ) {
//            importEvent.end( [ "result": "!createFile" ] )
//            throw AppError.issue( title: "Cannot write user document", details: documentURL )
//        }
//        importingFile.origin = documentURL
//
//        importEvent.end( [ "result": "success", "type": "created" ] )
//        AlertController( title: "Import Complete", message: documentURL.lastPathComponent, details:
//        """
//        Completed the import of \(importingFile) (\(importingFile.format)).
//        This export file was created on \(importingFile.exportDate).
//
//        This was a direct installation of the import data, not a merge import.
//        """ ).show( in: viewController.view )
//
//        await self.updateUserFiles()
//        return importingFile
//    }

    private func userDocuments() throws -> [URL] {
        var isDirectory: ObjCBool = false
        guard let documents = FileManager.groupDocuments,
              FileManager.default.fileExists(atPath: documents.path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else { return [] }

        return try FileManager.default.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil)
    }

    private func createURL(for user: User, in directory: URL? = nil, format: SpectreFormat) -> URL? {
        self.createURL(for: user.userName, in: directory, format: format)
    }

    private func createURL(for name: String, in directory: URL? = nil, format: SpectreFormat) -> URL? {
        guard let formatExtension = String.valid(spectre_format_extension(format)),
              let directory = directory ?? FileManager.groupDocuments
        else { return nil }

        return directory
            .appendingPathComponent(name.replacingOccurrences(of: "/", with: "_"), isDirectory: false)
            .appendingPathExtension(formatExtension)
    }

    @discardableResult
    public func updateUserFiles() -> [UserFile] {
        self.userFiles = self.loadUserFiles()
        return self.userFiles
    }

    private func clearUserFiles() {
        self.userFiles.removeAll()
    }

    private func loadUserFiles() -> [UserFile] {
        do {
            if self.userFilesMonitor == nil, let documentsPath = FileManager.groupDocuments?.path,
               FileManager.default.fileExists(atPath: documentsPath) ||
               (try? FileManager.default.createDirectory(atPath: documentsPath, withIntermediateDirectories: true)) != nil,
               let fd = none(if: open(documentsPath, O_EVTONLY), is: -1) {
                self.userFilesMonitor = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write)
            }

            return try self.userDocuments().compactMap { try UserFile(origin: $0) }
        }
        catch {
            err("Couldn't read user documents", data: error)
            return []
        }
    }

    // MARK: - LeakObserver

    nonisolated func willReportLeaks() {
        Task { await self.clearUserFiles() }
    }

    nonisolated func shouldCancelOperations() {}

    // MARK: - Types

    // TODO: Export
//    class ActivityItem: NSObject, UIActivityItemSource {
//        let user:     User
//        let format:   SpectreFormat
//        let redacted: Bool
//        let exportFile: URL
//
//        init(user: User, format: SpectreFormat, redacted: Bool) async throws {
//            self.user = user
//            self.format = format
//            self.redacted = redacted
//            self.exportFile = try await Marshal.shared.save(
//                user: self.user, in: URL(fileURLWithPath: NSTemporaryDirectory()),
//                format: self.format, redacted: self.redacted
//            )
//            super.init()
//            LeakRegistry.shared.register(self)
//        }
//
//        func text() -> String {
//            if self.redacted {
//                """
//                \(productName) export file (\(self.format)) for \(self.user)
//                NOTE: This is a SECURE export; access to the file does not expose its secrets.
//                ---
//                \(productName) v\(productVersion) (\(productBuild))
//                """
//            }
//            else {
//                """
//                \(productName) export (\(self.format)) for \(self.user)
//                NOTE: This export file's passwords are REVEALED.  Keep it safe!
//                ---
//                \(productName) v\(productVersion) (\(productBuild))
//                """
//            }
//        }
//
//        // MARK: - UIActivityItemSource
//
//        func activityViewControllerPlaceholderItem(_: UIActivityViewController)
//            -> Any {
//            self.user.description
//        }
//
//        func activityViewController(_ activityViewController: UIActivityViewController,
//                                    itemForActivityType activityType: UIActivity.ActivityType?)
//            -> Any? {
//            self.exportFile
//        }
//
//        func activityViewController(_ activityViewController: UIActivityViewController,
//                                    dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?)
//            -> String {
//            self.format.uti ?? ""
//        }
//
//        func activityViewController(_ activityViewController: UIActivityViewController,
//                                    subjectForActivityType activityType: UIActivity.ActivityType?)
//            -> String {
//            "\(productName) Export: \(self.user.userName)"
//        }
//
//        func activityViewController(_ activityViewController: UIActivityViewController,
//                                    thumbnailImageForActivityType activityType: UIActivity.ActivityType?, suggestedSize size: CGSize)
//            -> UIImage? {
//            self.user.avatar.image
//        }
//
//        func activityViewController(_ activityViewController: UIActivityViewController,
//                                    completed: Bool, forActivityType activityType: UIActivity.ActivityType?, returnedItems: [Any]?,
//                                    activityError error: Swift.Error?) {
//            try? FileManager.default.removeItem(at: self.exportFile)
//        }
//    }

    class UserFile: Hashable, Identifiable, Comparable, CustomStringConvertible, CredentialSupplier {
        public var origin: URL?
        public var file:   UnsafeMutablePointer<SpectreMarshalledFile>?

        public let format:     SpectreFormat
        public let exportDate: Date
        public let redacted:   Bool

        public let algorithm: SpectreAlgorithm
        public let avatar:    User.Avatar
        public let userName:  String
        public let identicon: SpectreIdenticon
        public var userKeyID: SpectreKeyID
        public let lastUsed:  Date

        public let biometricLock: Bool
        public let autofill:      Bool

        public var id: AnyHashable {
            [self.userName, self.origin]
        }

        static func load(origin: URL) throws -> UnsafeMutablePointer<SpectreMarshalledFile>? {
            var error:      NSError?
            var originData: Data?
            NSFileCoordinator().coordinate(readingItemAt: origin, error: &error) { origin in
                let securityScoped = origin.startAccessingSecurityScopedResource()
                originData = FileManager.default.contents(atPath: origin.path)
                if securityScoped {
                    origin.stopAccessingSecurityScopedResource()
                }
            }
            guard let documentData = originData
            else { return nil }

            guard let document = String(data: documentData, encoding: .utf8)
            else { throw AppError.issue("Cannot read user document", reason: origin) }

            guard let file = spectre_marshal_read(nil, document)
            else { throw AppError.internal(reason: "Couldn't allocate for unmarshalling", details: origin) }
            return file
        }

        convenience init?(user: User) throws {
            guard let file = user.file
            else { return nil }

            try self.init(file: file, origin: user.origin)
        }

        convenience init?(origin: URL) throws {
            guard let file = try UserFile.load(origin: origin)
            else { return nil }

            try self.init(file: file, origin: origin)
        }

        convenience init(data: Data, origin: URL? = nil) throws {
            guard let document = String(data: data, encoding: .utf8)
            else { throw AppError.issue("Cannot read user document", reason: origin) }

            guard let file = spectre_marshal_read(nil, document)
            else { throw AppError.internal(reason: "Couldn't allocate for unmarshalling", details: origin) }

            try self.init(file: file, origin: origin)
        }

        convenience init(file: UnsafeMutablePointer<SpectreMarshalledFile>, origin: URL? = nil) throws {
            guard file.pointee.error.type == .success
            else { throw AppError.marshal(file.pointee.error, title: "Cannot load user", details: origin) }
            guard let info = file.pointee.info?.pointee, info.format != .none, let userName = String.valid(info.userName)
            else { throw AppError.issue("Corrupted user document", reason: origin) }

            self.init(
                file: file, origin: origin,
                format: info.format, exportDate: Date(timeIntervalSince1970: TimeInterval(info.exportDate)),
                redacted: info.redacted, algorithm: info.algorithm, avatar: User.Avatar(rawValue: info.avatar) ?? .avatar_0,
                userName: userName, identicon: info.identicon, userKeyID: info.keyID,
                lastUsed: Date(timeIntervalSince1970: TimeInterval(info.lastUsed)),
                biometricLock: file.spectre_get(path: "user", "_ext_spectre", "biometricLock") ?? false,
                autofill: file.spectre_get(path: "user", "_ext_spectre", "autofill") ?? false
            )
        }

        init(file: UnsafeMutablePointer<SpectreMarshalledFile>? = nil, origin: URL? = nil,
             format: SpectreFormat, exportDate: Date, redacted: Bool, algorithm: SpectreAlgorithm,
             avatar: User.Avatar, userName: String, identicon: SpectreIdenticon, userKeyID: SpectreKeyID,
             lastUsed: Date, biometricLock: Bool, autofill: Bool) {
            self.origin = origin
            self.file = file
            self.format = format
            self.exportDate = exportDate
            self.redacted = redacted
            self.algorithm = algorithm
            self.avatar = avatar
            self.userName = userName
            self.identicon = identicon
            self.userKeyID = userKeyID
            self.lastUsed = lastUsed

            self.biometricLock = biometricLock
            self.autofill = autofill
            LeakRegistry.shared.register(self)

            for purchase in [
                "com.lyndir.masterpassword.products.generatelogins",
                "com.lyndir.masterpassword.products.generateanswers",
                "com.lyndir.masterpassword.products.touchid",
            ] {
                if let proof: String = file?.spectre_get(path: "user", "_ext_mpw", purchase),
                   let purchaseDigest = "\(self.userName)/\(purchase)".digest(salt: secrets.mpw.salt.b64Decrypt())?.hex().prefix(16),
                   proof == purchaseDigest {
                    AppConfig.shared.masterPasswordCustomer = true
                }

                file?.spectre_set(nil, path: "user", "_ext_mpw", purchase)
            }
        }

        public func resetKey() async throws {
            if spectre_id_valid([self.userKeyID]) {
                self.userKeyID = .unset
                self.file?.spectre_unset(path: "user", "key_id")

                if let file, let origin {
                    guard let data = String.valid(spectre_marshal_write(self.format, &self.file, nil), consume: true)?.data(using: .utf8),
                          file.pointee.error.type == .success
                    else {
                        throw AppError.marshal(file.pointee.error, title: "Issue writing file", details: self)
                    }

                    // Save export data to user's origin.
                    var coordinateError: NSError?, saveError: Error?
                    NSFileCoordinator().coordinate(writingItemAt: origin, error: &coordinateError) { userURL in
                        let securityScoped = userURL.startAccessingSecurityScopedResource()
                        if !FileManager.default.createFile(atPath: origin.path, contents: data) {
                            saveError = AppError.internal(reason: "Couldn't create file", details: userURL)
                        }
                        if securityScoped {
                            userURL.stopAccessingSecurityScopedResource()
                        }
                    }
                    if let error = coordinateError.flatMap({ AppError.issue("Couldn't access file", cause: $0) }) ?? saveError {
                        throw error
                    }
                }
            }
        }

        public func authenticate(using keyFactory: KeyFactory) async throws -> User {
            // Check origin for updates.
            if let origin = self.origin, let file = try UserFile.load(origin: origin) {
                self.file = file
            }
            guard let file = self.file
            else { throw AppError.issue("Missing user data") }

            // Authenticate against the file with the given keyFactory.
            guard let marshalledUser = spectre_marshal_auth(self.file, keyFactory.provide())?.pointee, file.pointee.error.type == .success
            else { throw AppError.marshal(file.pointee.error, title: "Issue authenticating user", details: self.userName) }
            // FIXME: marshalledUser is not deallocated?

            // Yield a fully authenticated user.
            return try await User(
                algorithm: marshalledUser.algorithm,
                avatar: User.Avatar(rawValue: marshalledUser.avatar) ?? .avatar_0,
                userName: String.valid(marshalledUser.userName) ?? self.userName,
                identicon: marshalledUser.identicon,
                userKeyID: self.userKeyID,
                resultType: marshalledUser.resultType,
                loginType: marshalledUser.loginType,
                loginState: .valid(marshalledUser.loginState),
                lastUsed: Date(timeIntervalSince1970: TimeInterval(marshalledUser.lastUsed)),
                origin: self.origin, file: file
            ) { user in

                for marshalledSite in
                    UnsafeBufferPointer(start: marshalledUser.sites, count: marshalledUser.sites_count) {
                    if let siteName = String.valid(marshalledSite.siteName) {
                        user.sites.append(Site(
                            user: user,
                            siteName: siteName,
                            algorithm: marshalledSite.algorithm,
                            counter: marshalledSite.counter,
                            resultType: marshalledSite.resultType,
                            resultState: .valid(marshalledSite.resultState),
                            loginType: marshalledSite.loginType,
                            loginState: .valid(marshalledSite.loginState),
                            url: .valid(marshalledSite.url),
                            domains: .init(String.valid(marshalledSite.domains)?.split(separator: ",").map(String.init) ?? []),
                            uses: marshalledSite.uses,
                            lastUsed: Date(timeIntervalSince1970: TimeInterval(marshalledSite.lastUsed))
                        ) { site in

                            for marshalledQuestion in
                                UnsafeBufferPointer(start: marshalledSite.questions, count: marshalledSite.questions_count) {
                                if let keyword = String.valid(marshalledQuestion.keyword) {
                                    site.questions.append(Question(
                                        site: site,
                                        keyword: keyword,
                                        resultType: marshalledQuestion.type,
                                        resultState: .valid(marshalledQuestion.state)
                                    ))
                                }
                            }
                        })
                    }
                }
            }
            .login(using: keyFactory)
        }

        // MARK: - Hashable

        func hash(into hasher: inout Hasher) {
            hasher.combine(self.origin)
            hasher.combine(self.format)
            hasher.combine(self.exportDate)
            hasher.combine(self.redacted)
            hasher.combine(self.algorithm)
            hasher.combine(self.avatar)
            hasher.combine(self.userName)
            hasher.combine(self.identicon)
            hasher.combine(self.userKeyID)
            hasher.combine(self.lastUsed)
            hasher.combine(self.biometricLock)
            hasher.combine(self.autofill)
        }

        static func == (lhs: UserFile, rhs: UserFile) -> Bool {
            lhs.origin == rhs.origin && lhs.format == rhs.format && lhs.exportDate - rhs.exportDate < 1 && lhs.redacted == rhs.redacted &&
                lhs.algorithm == rhs.algorithm && lhs.avatar == rhs.avatar && lhs.userName == rhs.userName &&
                lhs.identicon == rhs.identicon && lhs.userKeyID == rhs.userKeyID && lhs.lastUsed - rhs.lastUsed < 1 &&
                lhs.biometricLock == rhs.biometricLock && lhs.autofill == rhs.autofill
        }

        static func != (lhs: UserFile, rhs: UserFile) -> Bool {
            !(lhs == rhs)
        }

        static func == (lhs: User, rhs: UserFile) -> Bool {
            lhs.origin == rhs.origin && (lhs.exportDate ?? .init()) - rhs.exportDate < 1 &&
                lhs.algorithm == rhs.algorithm && lhs.avatar == rhs.avatar && lhs.userName == rhs.userName &&
                lhs.identicon == rhs.identicon && lhs.userKeyID == rhs.userKeyID && lhs.lastUsed - rhs.lastUsed < 1 &&
                lhs.biometricLock == rhs.biometricLock && lhs.autofill == rhs.autofill
        }

        static func != (lhs: User, rhs: UserFile) -> Bool {
            !(lhs == rhs)
        }

        // MARK: - Comparable

        static func < (lhs: UserFile, rhs: UserFile) -> Bool {
            if lhs.lastUsed != rhs.lastUsed {
                return lhs.lastUsed > rhs.lastUsed
            }

            return lhs.userName > rhs.userName
        }

        // MARK: - CustomStringConvertible

        var description: String {
            if let identicon = self.identicon.encoded() {
                "\(self.userName): \(identicon) [\(self.format)]"
            }
            else {
                "\(self.userName): \(self.userKeyID) [\(self.format)]"
            }
        }

        // MARK: - CredentialSupplier

        var credentialOwnerName: String {
            self.userName
        }

        var credentialOwnerRank: Int {
            Int(self.lastUsed.timeIntervalSinceReferenceDate)
        }

        var credentials: [AutoFill.Credential]? {
            guard self.autofill
            else { return nil }

            return self.file?.spectre_get(path: "sites")?.sorted(using: MappedComparator(order: .reverse) { site in
                site.spectre_get(path: "last_used") ?? ""
            }).compactMap { site in
                String.valid(site.obj_key).flatMap { siteName in
                    AutoFill.Credential(
                        supplier: self, siteName: siteName,
                        url: site.spectre_get(path: "_ext_spectre", "url"),
                        domains: site.spectre_get(path: "_ext_spectre", "domains")?.split(separator: ",").map(String.init) ?? []
                    )
                }
            }
        }
    }
}

extension SpectreMarshalError: LocalizedError {
    public var errorDescription: String? {
        .valid(self.message)
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
            case .errorUserSecret:
                return "The given personal secret is not valid. (\(self.type))"
            case .errorIllegal:
                return "An illegal value was specified. (\(self.type))"
            case .errorInternal:
                return "An internal system error interrupted marshalling. (\(self.type))"
            @unknown default:
                return "SpectreMarshalError (\(self.type))"
        }
    }
}

protocol MarshalObserver {
    func didChange(userFiles: [Marshal.UserFile])
}
