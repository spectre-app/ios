//
// Created by Maarten Billemont on 2019-05-11.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

class MPMarshal: Observable {
    public static let shared = MPMarshal()
    public let documentDirectory = (try? FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true ))
    public let observers         = Observers<MPMarshalObserver>()
    public var users: [UserInfo]? {
        didSet {
            if oldValue != self.users {
                self.observers.notify { $0.usersDidChange( self.users ) }
            }
        }
    }
    private var saving    = [ MPUser ]()
    private let saveQueue = DispatchQueue( label: "marshal" )

    // MARK: --- Interface ---

    public func setNeedsReload(_ completion: (([UserInfo]?) -> Void)? = nil) {
        DispatchQueue.mpw.perform {
            var users = [ UserInfo ]()
            for documentFile in self.userDocuments() {
                if let document = FileManager.default.contents( atPath: documentFile.path ),
                   !document.isEmpty,
                   let userDocument = String( data: document, encoding: .utf8 ),
                   let userInfo = mpw_marshal_read_info( userDocument )?.pointee, userInfo.format != .none,
                   let fullName = String( safeUTF8: userInfo.fullName ) {
                    users.append( UserInfo(
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
                    ) )
                }
            }

            self.users = users
            completion?( self.users )
        }
    }

    public func delete(userInfo: UserInfo) -> Bool {
        do {
            try FileManager.default.removeItem( at: userInfo.origin )
            self.users?.removeAll { $0 == userInfo }
            return true
        }
        catch {
            // TODO: handle error
            mperror( title: "Couldn't remove user document", context: userInfo.origin.lastPathComponent, error: error )
        }

        return false
    }

    public func setNeedsSave(user: MPUser) {
        guard !self.saving.contains( user )
        else {
            return
        }

        self.saving.append( user )
        self.saveQueue.asyncAfter( deadline: .now() + .seconds( 1 ) ) {
            do {
                let destination = try self.save( user: user, format: .default )
                if let origin = user.origin, origin != destination,
                   FileManager.default.fileExists( atPath: origin.path ) {
                    do {
                        try FileManager.default.removeItem( at: origin )
                    }
                    catch {
                        // TODO: handle error
                        mperror( title: "Cleanup issue", context: origin.lastPathComponent, error: error )
                    }
                }
                user.origin = destination
            }
            catch {
                // TODO: handle error
                mperror( title: "Issue saving", context: user.fullName, error: error )
            }
            self.saving.removeAll { $0 == user }
        }
    }

    @discardableResult
    public func save(user: MPUser, format: MPMarshalFormat, redacted: Bool = true, in directory: URL? = nil) throws -> URL {
        return try self.saveQueue.await {
            return try DispatchQueue.mpw.await {
                guard let documentFile = self.file( for: user, in: directory ?? self.documentDirectory, format: format )
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
                marshalledUser.pointee.defaultType = user.defaultType
                marshalledUser.pointee.lastUsed = time_t( user.lastUsed.timeIntervalSince1970 )

                for site in user.sites {
                    guard let marshalledSite = mpw_marshal_site( marshalledUser, site.siteName, site.resultType, site.counter, site.algorithm )
                    else {
                        throw Error.internal( details: "Couldn't marshal \(user): \(site)" )
                    }

                    site.resultState?.withCString { marshalledSite.pointee.resultState = $0 }
                    marshalledSite.pointee.loginType = site.loginType
                    site.loginState?.withCString { marshalledSite.pointee.loginState = $0 }
                    site.url?.withCString { marshalledSite.pointee.url = $0 }
                    marshalledSite.pointee.uses = UInt32( site.uses )
                    marshalledSite.pointee.lastUsed = time_t( site.lastUsed.timeIntervalSince1970 )
                }

                var error    = MPMarshalError( type: .success, description: nil )
                let document = mpw_marshal_write( format, marshalledUser, &error )
                if error.type == .success {
                    if let document = String( safeUTF8: document )?.data( using: .utf8 ) {
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

    public func `import`(data: Data) {
        return DispatchQueue.mpw.perform {
            guard let document = String( data: data, encoding: .utf8 )
            else {
                mperror( title: "Issue importing", context: "Missing import data" )
                return
            }
            guard let documentUser = mpw_marshal_read_info( document )?.pointee
            else {
                mperror( title: "Issue importing", context: "Import data malformed" )
                return
            }
            guard let documentName = String( safeUTF8: documentUser.fullName )
            else {
                mperror( title: "Issue importing", context: "Import missing fullName" )
                return
            }
            guard let documentFile = self.file( named: documentName, format: documentUser.format )
            else {
                mperror( title: "Issue importing", context: "No path for \(documentName)" )
                return
            }
            if !FileManager.default.createFile( atPath: documentFile.path, contents: data ) {
                mperror( title: "Issue importing", context: "Couldn't save \(documentFile.lastPathComponent)" )
                return
            }

            self.setNeedsReload()
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

        func description() -> String {
            let appName    = PearlInfoPlist.get().cfBundleDisplayName ?? ""
            let appVersion = PearlInfoPlist.get().cfBundleShortVersionString ?? ""
            let appBuild   = PearlInfoPlist.get().cfBundleVersion ?? ""

            if self.redacted {
                return """
                       \(appName) export file (\(self.format.name)) for \(self.user.fullName): \(self.user.identicon.text() ?? "")
                       NOTE: This is a SECURE export; access to the file does not expose its secrets.
                       ---
                       \(appName) v\(appVersion) (\(appBuild))
                       """
            }
            else {
                return """
                       \(appName) export (\(self.format.name)) for \(self.user.fullName): \(self.user.identicon.text() ?? "")
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
            self.cleanup.removeAll { nil != (try? FileManager.default.removeItem( at: $0 )) }
        }
    }

    class UserInfo: NSObject {
        public let origin:   URL
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

        init(origin: URL, document: String, format: MPMarshalFormat, exportDate: Date, redacted: Bool,
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

        public func authenticate(masterPassword: String, _ completion: @escaping (MPUser?, MPMarshalError) -> Void) {
            DispatchQueue.mpw.perform {
                provideMasterKeyWith( password: masterPassword ) { masterKeyProvider in
                    var error = MPMarshalError( type: .success, description: nil )
                    if let marshalledUser = mpw_marshal_read( self.document, self.format, masterKeyProvider, &error )?.pointee {
                        let user = MPUser(
                                algorithm: marshalledUser.algorithm,
                                avatar: MPUser.Avatar.decode( avatar: marshalledUser.avatar ),
                                fullName: String( safeUTF8: marshalledUser.fullName ) ?? self.fullName,
                                identicon: marshalledUser.identicon,
                                masterKeyID: self.keyID,
                                defaultType: marshalledUser.defaultType,
                                lastUsed: Date( timeIntervalSince1970: TimeInterval( marshalledUser.lastUsed ) ),
                                origin: self.origin
                        )
                        guard user.mpw_authenticate( masterPassword: masterPassword )
                        else {
                            return completion( nil, error )
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
                                        uses: UInt( site.uses ),
                                        lastUsed: Date( timeIntervalSince1970: TimeInterval( site.lastUsed ) )
                                ) )
                            }
                        }
                        return completion( user, error )
                    }
                    else {
                        return completion( nil, error )
                    }
                }
            }
        }

        // MARK: --- Equatable ---

        static func ==(lhs: UserInfo, rhs: UserInfo) -> Bool {
            return lhs.fullName == rhs.fullName
        }
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
