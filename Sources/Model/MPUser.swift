//
// Created by Maarten Billemont on 2018-03-04.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPUser: Hashable, Comparable, CustomStringConvertible, Observable, MPSiteObserver, MPUserObserver {
    // TODO: figure out how to batch updates or suspend changes until sites marshalling/authenticate fully complete.
    public let observers = Observers<MPUserObserver>()

    public var algorithm: MPAlgorithmVersion {
        didSet {
            if oldValue != self.algorithm {
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }
    public var avatar: Avatar {
        didSet {
            if oldValue != self.avatar {
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }
    public let fullName: String
    public var identicon: MPIdenticon {
        didSet {
            if oldValue != self.identicon {
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }
    public var masterKeyID: String? {
        didSet {
            if oldValue != self.masterKeyID {
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }
    public var defaultType: MPResultType {
        didSet {
            if oldValue != self.defaultType {
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }
    public var lastUsed: Date {
        didSet {
            if oldValue != self.lastUsed {
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }
    public var maskPasswords = false {
        didSet {
            if oldValue != self.maskPasswords,
               self.mpw_set( self.maskPasswords, path: "user", "_ext_mpw", "maskPasswords" ) {
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }
    public var biometricLock = false {
        didSet {
            if oldValue != self.biometricLock,
               self.mpw_set( self.biometricLock, path: "user", "_ext_mpw", "biometricLock" ) {
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }
    public var file:   MPMarshalledFile
    public var origin: URL?

    public var masterKey: MPMasterKey? {
        didSet {
            if oldValue != self.masterKey {
                if let _ = self.masterKey {
                    self.observers.notify { $0.userDidLogin( self ) }
                }
                else {
                    self.observers.notify { $0.userDidLogout( self ) }
                }
            }
        }
    }
    public var sites = [ MPSite ]() {
        didSet {
            if oldValue != self.sites {
                self.sites.forEach { site in site.observers.register( observer: self ) }
                self.observers.notify { $0.userDidUpdateSites( self ) }
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }
    var description: String {
        if let identicon = self.identicon.encoded() {
            return "\(self.fullName): \(identicon)"
        }
        else if let masterKeyID = self.masterKeyID {
            return "\(self.fullName): \(masterKeyID)"
        }
        else {
            return "\(self.fullName)"
        }
    }

    // MARK: --- Life ---

    init(algorithm: MPAlgorithmVersion? = nil, avatar: Avatar = .avatar_0, fullName: String,
         identicon: MPIdenticon = MPIdenticonUnset, masterKeyID: String? = nil,
         defaultType: MPResultType? = nil, lastUsed: Date = Date(), origin: URL? = nil,
         file: MPMarshalledFile = mpw_marshal_file( nil, nil, nil, nil ).pointee) {
        self.algorithm = algorithm ?? .versionCurrent
        self.avatar = avatar
        self.fullName = fullName
        self.identicon = identicon
        self.masterKeyID = masterKeyID
        self.defaultType = defaultType ?? .default
        self.lastUsed = lastUsed
        self.origin = origin
        self.file = file

        if self.file.data == nil {
            mpw_marshal_file( &self.file, nil, mpw_marshal_data_new(), nil );
        }

        self.maskPasswords = self.mpw_get( path: "user", "_ext_mpw", "maskPasswords" )
        self.biometricLock = self.mpw_get( path: "user", "_ext_mpw", "biometricLock" )
        self.observers.register( observer: self )
    }

    // MARK: Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine( self.fullName )
    }

    static func ==(lhs: MPUser, rhs: MPUser) -> Bool {
        lhs.fullName == rhs.fullName
    }

    // MARK: Comparable

    static func <(lhs: MPUser, rhs: MPUser) -> Bool {
        lhs.fullName > rhs.fullName
    }

    // MARK: --- MPSiteObserver ---

    func siteDidChange(_ site: MPSite) {
        MPMarshal.shared.setNeedsSave( user: self )
    }

    // MARK: --- MPUserObserver ---

    func userDidChange(_ user: MPUser) {
        MPMarshal.shared.setNeedsSave( user: self )
    }

    // MARK: --- Interface ---

    public func use() {
        self.lastUsed = Date()
    }

    // MARK: --- mpw ---

    public func mpw_get(path: String...) -> Bool {
        withVaStrings( path ) { mpw_marshal_data_vget_bool( self.file.data, $0 ) }
    }

    public func mpw_get(path: String...) -> Double {
        withVaStrings( path ) { mpw_marshal_data_vget_num( self.file.data, $0 ) }
    }

    public func mpw_get(path: String...) -> String? {
        withVaStrings( path ) { String( safeUTF8: mpw_marshal_data_vget_str( self.file.data, $0 ) ) }
    }

    public func mpw_set(_ value: Bool, path: String...) -> Bool {
        withVaStrings( path ) { mpw_marshal_data_vset_bool( value, self.file.data, $0 ) }
    }

    public func mpw_set(_ value: Double, path: String...) -> Bool {
        withVaStrings( path ) { mpw_marshal_data_vset_num( value, self.file.data, $0 ) }
    }

    public func mpw_set(_ value: String?, path: String...) -> Bool {
        withVaStrings( path ) { mpw_marshal_data_vset_str( value, self.file.data, $0 ) }
    }

    @discardableResult
    public func mpw_authenticate(masterPassword: String) -> Bool {
        DispatchQueue.mpw.await {
            self.identicon = mpw_identicon( self.fullName, masterPassword )

            if let authKey = mpw_master_key( self.fullName, masterPassword, .versionCurrent ),
               let authKeyID = String( safeUTF8: mpw_id_buf( authKey, MPMasterKeySize ) ) {

                if let masterKeyID = self.masterKeyID {
                    if masterKeyID != authKeyID {
                        return false
                    }
                }
                else {
                    self.masterKeyID = authKeyID
                }

                self.masterKey = authKey
                self.use()
                return true
            }

            return false
        }
    }

    // MARK: --- Types ---

    enum Avatar: Int, CaseIterable {
        static let userAvatars: [Avatar] = [
            .avatar_0, .avatar_1, .avatar_2, .avatar_3, .avatar_4, .avatar_5, .avatar_6, .avatar_7, .avatar_8, .avatar_9,
            .avatar_10, .avatar_11, .avatar_12, .avatar_13, .avatar_14, .avatar_15, .avatar_16, .avatar_17, .avatar_18 ]

        case avatar_0, avatar_1, avatar_2, avatar_3, avatar_4, avatar_5, avatar_6, avatar_7, avatar_8, avatar_9,
             avatar_10, avatar_11, avatar_12, avatar_13, avatar_14, avatar_15, avatar_16, avatar_17, avatar_18,
             avatar_add

        public static func decode(avatar: UInt32) -> Avatar {
            Avatar.userAvatars.indices.contains( Int( avatar ) ) ? Avatar.userAvatars[Int( avatar )]: .avatar_0
        }

        public func encode() -> UInt32 {
            UInt32( Avatar.userAvatars.firstIndex( of: self ) ?? 0 )
        }

        public func image() -> UIImage? {
            switch self {
                case .avatar_add:
                    return UIImage.init( named: "avatar-add" )
                default:
                    return UIImage.init( named: "avatar-\(self.rawValue)" )
            }
        }

        public mutating func next() {
            self = Avatar.userAvatars[((Avatar.userAvatars.firstIndex( of: self ) ?? -1) + 1) % Avatar.userAvatars.count]
        }
    }
}

protocol MPUserObserver {
    func userDidLogin(_ user: MPUser)
    func userDidLogout(_ user: MPUser)

    func userDidChange(_ user: MPUser)
    func userDidUpdateSites(_ user: MPUser)
}

extension MPUserObserver {
    func userDidLogin(_ user: MPUser) {
    }

    func userDidLogout(_ user: MPUser) {
    }

    func userDidChange(_ user: MPUser) {
    }

    func userDidUpdateSites(_ user: MPUser) {
    }
}
