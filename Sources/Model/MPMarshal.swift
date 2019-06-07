//
// Created by Maarten Billemont on 2019-05-11.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

class MPMarshal {
    public static let shared = MPMarshal()
    public let observers = Observers<MPMarshalObserver>()
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
                let documents = try FileManager.default.url( for: .documentDirectory, in: .userDomainMask,
                                                             appropriateFor: nil, create: true )
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
                                algorithm: userInfo.algorithm,
                                fullName: fullName,
                                avatar: .avatar_0,
                                keyID: String( safeUTF8: userInfo.keyID ),
                                redacted: userInfo.redacted,
                                date: Date( timeIntervalSince1970: TimeInterval( userInfo.date ) )
                        ) )
                    }
                }

                self.users = users
            }
            catch let e {
                err( "caught: \(e)" )
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
        catch let e {
            err( "caught: \(e)" )
        }

        return false
    }

    public func save(user: MPUser) {
        guard !self.saving.contains( user )
        else {
            return
        }

        print("Start saving \(user.fullName)")
        self.saving.append( user )
        self.saveQueue.asyncAfter( deadline: .now() + .seconds( 1 ) ) {
            DispatchQueue.mpw.await {
                provideMasterKeyWith( key: user.masterKey ) { masterKeyProvider in
                    do {
                        guard let marshalledUser = mpw_marshal_user( user.fullName, masterKeyProvider, user.algorithm )
                        else {
                            err( "couldn't marshal user: \(user)" )
                            return
                        }

                        marshalledUser.pointee.avatar = UInt32( user.avatar.rawValue )
                        marshalledUser.pointee.defaultType = user.defaultType
                        marshalledUser.pointee.lastUsed = time_t( user.lastUsed.timeIntervalSince1970 )

                        for site in user.sites {
                            guard let marshalledSite = mpw_marshal_site( marshalledUser, site.siteName, site.resultType, site.counter, site.algorithm )
                            else {
                                err( "couldn't marshal site: \(site)" )
                                return
                            }

                            site.resultState?.withCString { marshalledSite.pointee.resultState = $0 }
                            site.loginState?.withCString { marshalledSite.pointee.loginState = $0 }
                            marshalledSite.pointee.loginType = site.loginType
                            site.url?.withCString { marshalledSite.pointee.url = $0 }
                            marshalledSite.pointee.uses = UInt32( site.uses )
                            marshalledSite.pointee.lastUsed = time_t( site.lastUsed.timeIntervalSince1970 )
                        }

                        let format   = MPMarshalFormat.default
                        var error    = MPMarshalError( type: .success, description: nil )
                        let document = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate( capacity: 0 )
                        document.initialize( to: nil )
                        let success = mpw_marshal_write( document, format, marshalledUser, &error )
                        inf( "saveToFile(\(user.fullName)): \(success), \(String( safeUTF8: error.description ) ?? "n/a")" )

                        if success,
                           let formatExtension = String( safeUTF8: mpw_marshal_format_extension( format ) ),
                           let document = document.pointee,
                           let userDocument = String( safeUTF8: document ) {
                            let documentPath = try FileManager.default.url( for: .documentDirectory, in: .userDomainMask,
                                                                            appropriateFor: nil, create: true )
                                                                      .appendingPathComponent( user.fullName, isDirectory: false )
                                                                      .appendingPathExtension( formatExtension ).path
                            if FileManager.default.createFile( atPath: documentPath, contents: userDocument.data( using: .utf8 ) ) {
                                inf( "written to: \(documentPath)" )

                                if !(self.users?.contains { $0.path == documentPath } ?? false) {
                                    self.reloadUsers()
                                }
                            }
                        }
                    }
                    catch let e {
                        err( "caught: \(e)" )
                    }
                }
            }

            print( "Done saving \(user.fullName)" )
            self.saving.removeAll { $0 == user }
        }
    }

    // MARK: --- Interface ---

    class UserInfo: NSObject {
        public let path:      String
        public let document:  String
        public let format:    MPMarshalFormat
        public let algorithm: MPAlgorithmVersion
        public let fullName:  String
        public let avatar:    MPUser.Avatar
        public let keyID:     String?
        public let redacted:  Bool
        public let date:      Date

        init(path: String, document: String, format: MPMarshalFormat, algorithm: MPAlgorithmVersion, fullName: String, avatar: MPUser.Avatar,
             keyID: String?, redacted: Bool, date: Date) {
            self.path = path
            self.document = document
            self.format = format
            self.algorithm = algorithm
            self.fullName = fullName
            self.avatar = avatar
            self.keyID = keyID
            self.redacted = redacted
            self.date = date
        }

        public func authenticate(masterPassword: String, _ completion: @escaping (MPUser?, MPMarshalError) -> Void) {
            DispatchQueue.mpw.perform {
                provideMasterKeyWith( password: masterPassword ) { masterKeyProvider in
                    var error = MPMarshalError( type: .success, description: nil )
                    if let marshalledUser = mpw_marshal_read( self.document, self.format, masterKeyProvider, &error )?.pointee {
                        let user = MPUser(
                                named: String( safeUTF8: marshalledUser.fullName ) ?? self.fullName,
                                avatar: MPUser.Avatar( rawValue: Int( marshalledUser.avatar ) ) ?? .avatar_0,
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
    return mpw_masterKey( fullName, currentMasterPassword, algorithm )
}

private func provideMasterKeyWith<R>(key: MPMasterKey?, _ perform: (@escaping MPMasterKeyProvider) -> R) -> R {
    currentMasterKey = key
    let result = perform( __masterKeyObjectProvider )
    currentMasterKey = nil

    return result
}

private func provideMasterKeyWith<R>(password: String?, _ perform: (@escaping MPMasterKeyProvider) -> R) -> R {
    currentMasterPassword = password
    let result = perform( __masterKeyPasswordProvider )
    currentMasterPassword = nil

    return result
}
