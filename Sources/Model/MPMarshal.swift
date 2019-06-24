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

    public func reloadUsers(_ completion: (([UserInfo]?) -> Void)? = nil) {
        DispatchQueue.mpw.perform {
            do {
                var users     = [ UserInfo ]()
                let documents = try FileManager.default.url( for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true )
                for documentName in try FileManager.default.contentsOfDirectory( atPath: documents.path ) {
                    let documentPath = documents.appendingPathComponent( documentName ).path
                    if let document = FileManager.default.contents( atPath: documentPath ),
                       !document.isEmpty,
                       let userDocument = String( data: document, encoding: .utf8 ),
                       let userInfo = mpw_marshal_read_info( userDocument )?.pointee, userInfo.format != .none,
                       let fullName = String( safeUTF8: userInfo.fullName ) {
                        users.append( UserInfo(
                                path: documentPath,
                                document: userDocument,
                                format: userInfo.format,
                                exportDate: Date( timeIntervalSince1970: TimeInterval( userInfo.exportDate ) ),
                                redacted: userInfo.redacted,
                                algorithm: userInfo.algorithm,
                                avatar: MPUser.Avatar.decode( avatar: userInfo.avatar ),
                                fullName: fullName,
                                keyID: String( safeUTF8: userInfo.keyID ),
                                lastUsed: Date( timeIntervalSince1970: TimeInterval( userInfo.lastUsed ) )
                        ) )
                    }
                }

                self.users = users
            }
            catch {
                // TODO: handle error
                err( "reloadUsers: \(error)" )
                self.users = nil
            }

            completion?( self.users )
        }
    }

    public func delete(userInfo: UserInfo) -> Bool {
        do {
            let documents = try FileManager.default.url( for: .documentDirectory, in: .userDomainMask,
                                                         appropriateFor: nil, create: true )
            for documentPath in try FileManager.default.contentsOfDirectory( atPath: documents.path ) {
                let path = documents.appendingPathComponent( documentPath ).path
                if FileManager.default.fileExists( atPath: path ) {
                    try FileManager.default.removeItem( atPath: path )
                    self.users?.removeAll { $0 == userInfo }
                    return true
                }
            }
        }
        catch {
            // TODO: handle error
            err( "delete: \(error)" )
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
            self.save( user: user ) // TODO: handle error?
            self.saving.removeAll { $0 == user }
        }
    }

    @discardableResult
    public func save(user: MPUser, redacted: Bool = true, format: MPMarshalFormat? = nil, in directory: URL? = nil) -> URL? {
        return self.saveQueue.await {
            return DispatchQueue.mpw.await {
                if let documentFile = self.file( for: user, in: directory ?? self.documentDirectory ),
                   let documentData = self.export( user: user, redacted: redacted, format: format ),
                   FileManager.default.createFile( atPath: documentFile.path, contents: documentData ) {
                    self.reloadUsers()
                    return documentFile
                }

                return nil
            }
        }
    }

    public func export(user: MPUser, redacted: Bool, format: MPMarshalFormat? = nil) -> Data? {
        return DispatchQueue.mpw.await {
            provideMasterKeyWith( key: user.masterKey ) { masterKeyProvider in
                guard let marshalledUser = mpw_marshal_user( user.fullName, masterKeyProvider, user.algorithm )
                else {
                    // TODO: handle error
                    err( "couldn't marshal user: \(user)" )
                    return nil
                }

                marshalledUser.pointee.redacted = redacted
                marshalledUser.pointee.avatar = user.avatar.encode()
                marshalledUser.pointee.defaultType = user.defaultType
                marshalledUser.pointee.lastUsed = time_t( user.lastUsed.timeIntervalSince1970 )

                for site in user.sites {
                    guard let marshalledSite = mpw_marshal_site( marshalledUser, site.siteName, site.resultType, site.counter, site.algorithm )
                    else {
                        // TODO: handle error
                        err( "couldn't marshal site: \(site)" )
                        return nil
                    }

                    site.resultState?.withCString { marshalledSite.pointee.resultState = $0 }
                    site.loginState?.withCString { marshalledSite.pointee.loginState = $0 }
                    marshalledSite.pointee.loginType = site.loginType
                    site.url?.withCString { marshalledSite.pointee.url = $0 }
                    marshalledSite.pointee.uses = UInt32( site.uses )
                    marshalledSite.pointee.lastUsed = time_t( site.lastUsed.timeIntervalSince1970 )
                }

                var error    = MPMarshalError( type: .success, description: nil )
                let document = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate( capacity: 0 )
                document.initialize( to: nil )
                if mpw_marshal_write( document, format ?? user.format, marshalledUser, &error ), error.type == .success,
                   let documentData = String( safeUTF8: document.pointee )?.data( using: .utf8 ) {
                    return documentData
                }

                // TODO: handle error
                err( "marshal error: \(error)" )
                return nil
            }
        }
    }

    public func `import`(data: Data) {
        return DispatchQueue.mpw.perform {
            if let document = String( data: data, encoding: .utf8 ),
               let documentUser = mpw_marshal_read_info( document )?.pointee,
               let documentName = String( safeUTF8: documentUser.fullName ),
               let documentFile = self.file( named: documentName, format: documentUser.format ),
               FileManager.default.createFile( atPath: documentFile.path, contents: data ) {
                self.reloadUsers()
            }
            // TODO: handle error
        }
    }

    private func file(for user: MPUser, in directory: URL? = nil, format: MPMarshalFormat? = nil) -> URL? {
        return self.file( named: user.fullName, in: directory, format: format ?? user.format )
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

    class ActivityItem: NSObject, UIActivityItemSource {
        let user:     MPUser
        let redacted: Bool
        var cleanup = [ URL ]()

        init(user: MPUser, redacted: Bool) {
            self.user = user
            self.redacted = redacted
        }

        func description() -> String {
            if self.redacted {
                return """
                       \(PearlInfoPlist.get().cfBundleDisplayName ?? "") export file for \(user.fullName): \(user.identicon?.text() ?? "")
                       NOTE: This is a SECURE export; access to the file does not expose its secrets.
                       ---
                       \(PearlInfoPlist.get().cfBundleDisplayName ?? "") v\(PearlInfoPlist.get().cfBundleShortVersionString ?? "") (\(PearlInfoPlist.get().cfBundleVersion ?? ""))
                       """
            }
            else {
                return """
                       \(PearlInfoPlist.get().cfBundleDisplayName ?? "") export for \(user.fullName): \(user.identicon?.text() ?? "")
                       NOTE: This export file's passwords are REVEALED.  Keep it safe!
                       ---
                       \(PearlInfoPlist.get().cfBundleDisplayName ?? "") v\(PearlInfoPlist.get().cfBundleShortVersionString ?? "") (\(PearlInfoPlist.get().cfBundleVersion ?? ""))
                       """
            }
        }

        func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
            if let identicon = self.user.identicon {
                return "\(self.user.fullName): \(identicon.text())"
            }
            else if let keyID = self.user.masterKeyID {
                return "\(self.user.fullName): \(keyID)"
            }
            else {
                return "\(self.user.fullName)"
            }
        }

        func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
            if let exportFile = MPMarshal.shared.save( user: self.user, redacted: self.redacted, in: URL( fileURLWithPath: NSTemporaryDirectory() ) ) {
                self.cleanup.append( exportFile )
                return exportFile
            }

            return nil
        }

        func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
            return self.user.format.uti ?? ""
        }

        func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
            return "\(PearlInfoPlist.get().cfBundleDisplayName ?? "") Export: \(self.user.fullName)"
        }

        func activityViewController(_ activityViewController: UIActivityViewController, thumbnailImageForActivityType activityType: UIActivity.ActivityType?, suggestedSize size: CGSize) -> UIImage? {
            return self.user.avatar.image()
        }

        func activityViewController(_ activityViewController: UIActivityViewController, completed: Bool, forActivityType activityType: UIActivity.ActivityType?, returnedItems: [Any]?, activityError error: Error?) {
            self.cleanup.removeAll { nil != (try? FileManager.default.removeItem( at: $0 )) }
        }
    }

    class UserInfo: NSObject {
        public let path:       String
        public let document:   String
        public let format:     MPMarshalFormat
        public let exportDate: Date
        public let redacted:   Bool

        public let algorithm: MPAlgorithmVersion
        public let avatar:    MPUser.Avatar
        public let fullName:  String
        public let keyID:     String?
        public let lastUsed:  Date

        init(path: String, document: String, format: MPMarshalFormat, exportDate: Date, redacted: Bool,
             algorithm: MPAlgorithmVersion, avatar: MPUser.Avatar, fullName: String, keyID: String?, lastUsed: Date) {
            self.path = path
            self.document = document
            self.format = format
            self.exportDate = exportDate
            self.redacted = redacted
            self.algorithm = algorithm
            self.avatar = avatar
            self.fullName = fullName
            self.keyID = keyID
            self.lastUsed = lastUsed
        }

        public func authenticate(masterPassword: String, _ completion: @escaping (MPUser?, MPMarshalError) -> Void) {
            DispatchQueue.mpw.perform {
                provideMasterKeyWith( password: masterPassword ) { masterKeyProvider in
                    var error = MPMarshalError( type: .success, description: nil )
                    if let marshalledUser = mpw_marshal_read( self.document, self.format, masterKeyProvider, &error )?.pointee {
                        let user = MPUser(
                                named: String( safeUTF8: marshalledUser.fullName ) ?? self.fullName,
                                avatar: MPUser.Avatar.decode( avatar: marshalledUser.avatar ),
                                format: self.format,
                                algorithm: marshalledUser.algorithm,
                                defaultType: marshalledUser.defaultType,
                                lastUsed: Date( timeIntervalSince1970: TimeInterval( marshalledUser.lastUsed ) ),
                                masterKeyID: self.keyID
                        )
                        guard user.mpw_authenticate( masterPassword: masterPassword )
                        else {
                            return completion( nil, error )
                        }

                        for s in 0..<marshalledUser.sites_count {
                            let site = (marshalledUser.sites + s).pointee
                            if let siteName = String( safeUTF8: site.name ) {
                                user.sites.append( MPSite(
                                        user: user,
                                        named: siteName,
                                        algorithm: site.algorithm,
                                        counter: site.counter,
                                        resultType: site.resultType,
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

@objc
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

private func provideMasterKeyWith<R>(key: MPMasterKey?, _ perform: (@escaping MPMasterKeyProvider) -> R) -> R {
    currentMasterKey = key
    defer {
        currentMasterKey = nil
    }

    return perform( __masterKeyObjectProvider )
}

private func provideMasterKeyWith<R>(password: String?, _ perform: (@escaping MPMasterKeyProvider) -> R) -> R {
    currentMasterPassword = password
    defer {
        currentMasterPassword = nil
    }

    return perform( __masterKeyPasswordProvider )
}
