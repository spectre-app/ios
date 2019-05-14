//
// Created by Maarten Billemont on 2018-03-04.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPUser: NSObject, MPSiteObserver, MPUserObserver {
    public let observers = Observers<MPUserObserver>()

    public let fullName: String
    public var avatar: Avatar {
        didSet {
            self.observers.notify { $0.userDidChange( self ) }
        }
    }

    public var algorithm: MPAlgorithmVersion {
        didSet {
            self.observers.notify { $0.userDidChange( self ) }
        }
    }
    public var defaultType: MPResultType {
        didSet {
            self.observers.notify { $0.userDidChange( self ) }
        }
    }
    public var lastUsed: Date {
        didSet {
            self.observers.notify { $0.userDidChange( self ) }
        }
    }

    public var masterKeyID: String? {
        didSet {
            self.observers.notify { $0.userDidChange( self ) }
        }
    }
    public var masterKey: MPMasterKey? {
        didSet {
            if let _ = self.masterKey {
                self.observers.notify { $0.userDidLogin( self ) }
            }
            else {
                self.observers.notify { $0.userDidLogout( self ) }
            }
        }
    }
    public var sites = [ MPSite ]() {
        didSet {
            self.sites.forEach { site in site.observers.register( self ) }
            self.observers.notify { $0.userDidUpdateSites( self ) }
            self.observers.notify { $0.userDidChange( self ) }
        }
    }

    // MARK: --- Life ---

    init(named name: String, avatar: Avatar = .avatar_0,
         algorithm: MPAlgorithmVersion? = nil, defaultType: MPResultType? = nil, lastUsed: Date = Date(), masterKeyID: String? = nil) {
        self.fullName = name
        self.avatar = avatar
        self.algorithm = algorithm ?? .versionCurrent
        self.defaultType = defaultType ?? .default
        self.lastUsed = lastUsed
        self.masterKeyID = masterKeyID
        super.init()

        self.observers.register( self )
    }

    // MARK: --- MPSiteObserver ---

    func siteDidChange(_ site: MPSite) {
    }

    // MARK: --- MPUserObserver ---

    func userDidLogin(_ user: MPUser) {
    }

    func userDidLogout(_ user: MPUser) {
    }

    func userDidChange(_ user: MPUser) {
        MPMarshal.shared.save( user: self )
    }

    func userDidUpdateSites(_ user: MPUser) {
    }

    // MARK: --- Interface ---

    @discardableResult
    func mpw_authenticate(masterPassword: String) -> Bool {
        if let authKey = mpw_masterKey( self.fullName, masterPassword, .versionCurrent ),
           let authKeyID = String( safeUtf8String: mpw_id_buf( authKey, MPMasterKeySize ) ) {
            if let masterKeyID = self.masterKeyID {
                if masterKeyID != authKeyID {
                    return false
                }
            }
            else {
                self.masterKeyID = authKeyID
            }

            self.masterKey = authKey
            return true
        }

        return false
    }

    // MARK: --- Types ---

    enum Avatar: Int {
        static let userAvatars: [Avatar] = [
            .avatar_0, .avatar_1, .avatar_2, .avatar_3, .avatar_4, .avatar_5, .avatar_6, .avatar_7, .avatar_8, .avatar_9,
            .avatar_10, .avatar_11, .avatar_12, .avatar_13, .avatar_14, .avatar_15, .avatar_16, .avatar_17, .avatar_18 ]

        case avatar_0, avatar_1, avatar_2, avatar_3, avatar_4, avatar_5, avatar_6, avatar_7, avatar_8, avatar_9,
             avatar_10, avatar_11, avatar_12, avatar_13, avatar_14, avatar_15, avatar_16, avatar_17, avatar_18,
             avatar_add

        func image() -> UIImage? {
            switch self {
                case .avatar_add:
                    return UIImage.init( named: "avatar-add" )
                default:
                    return UIImage.init( named: "avatar-\(self.rawValue)" )
            }
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
