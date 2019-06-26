//
// Created by Maarten Billemont on 2018-03-04.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPUser: NSObject, Observable, MPSiteObserver, MPUserObserver {
    public let observers = Observers<MPUserObserver>()

    public let fullName: String
    public var identicon: MPIdenticon? {
        didSet {
            if oldValue != self.identicon {
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
    public var algorithm: MPAlgorithmVersion {
        didSet {
            if oldValue != self.algorithm {
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
    public var format: MPMarshalFormat {
        didSet {
            if oldValue != self.format {
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }
    public var origin: URL?

    public var masterKeyID: String? {
        didSet {
            if oldValue != self.masterKeyID {
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }
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
    override var description: String {
        if let identicon = self.identicon {
            return "\(self.fullName): \(identicon.text())"
        }
        else if let keyID = self.masterKeyID {
            return "\(self.fullName): \(keyID)"
        }
        else {
            return "\(self.fullName)"
        }
    }

    // MARK: --- Life ---

    init(algorithm: MPAlgorithmVersion? = nil, avatar: Avatar = .avatar_0, fullName: String, identicon: MPIdenticon, masterKeyID: String? = nil,
         defaultType: MPResultType? = nil, lastUsed: Date = Date(), format: MPMarshalFormat = .default, origin: URL? = nil) {
        self.algorithm = algorithm ?? .versionCurrent
        self.avatar = avatar
        self.fullName = fullName
        self.identicon = identicon
        self.masterKeyID = masterKeyID
        self.defaultType = defaultType ?? .default
        self.lastUsed = lastUsed
        self.format = format
        self.origin = origin
        super.init()

        self.observers.register( observer: self )
    }

    // MARK: --- MPSiteObserver ---

    func siteDidChange(_ site: MPSite) {
        MPMarshal.shared.setNeedsSave( user: self )
    }

    // MARK: --- MPUserObserver ---

    func userDidLogin(_ user: MPUser) {
    }

    func userDidLogout(_ user: MPUser) {
    }

    func userDidChange(_ user: MPUser) {
        MPMarshal.shared.setNeedsSave( user: self )
    }

    func userDidUpdateSites(_ user: MPUser) {
    }

    // MARK: --- Interface ---

    public func use() {
        self.lastUsed = Date()
    }

    // MARK: --- mpw ---

    @discardableResult
    public func mpw_authenticate(masterPassword: String) -> Bool {
        return DispatchQueue.mpw.await {
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
            return Avatar.userAvatars.indices.contains( Int( avatar ) ) ? Avatar.userAvatars[Int( avatar )]: .avatar_0
        }

        public func encode() -> UInt32 {
            return UInt32( Avatar.userAvatars.firstIndex( of: self ) ?? 0 )
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

@objc

protocol MPUserObserver {
    func userDidLogin(_ user: MPUser)
    func userDidLogout(_ user: MPUser)

    func userDidChange(_ user: MPUser)
    func userDidUpdateSites(_ user: MPUser)
}
