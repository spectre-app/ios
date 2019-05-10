//
// Created by Maarten Billemont on 2018-03-04.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPUser: NSObject, MPSiteObserver, MPUserObserver {
    public let observers = Observers<MPUserObserver>()

    public let fullName: String
    public var avatar: MPUserAvatar {
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

    public var masterKeyID: MPKeyID? {
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

    init(named name: String, avatar: MPUserAvatar = .avatar_0,
         algorithm: MPAlgorithmVersion? = nil, defaultType: MPResultType? = nil, masterKeyID: MPKeyID? = nil) {
        self.fullName = name
        self.avatar = avatar
        self.algorithm = algorithm ?? .versionCurrent
        self.defaultType = defaultType ?? .default
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
    }

    func userDidUpdateSites(_ user: MPUser) {
    }

    // MARK: --- Interface ---

    @discardableResult
    func authenticate(masterPassword: String) -> Bool {
        if let authKey = (masterPassword.withCString { masterPassword in
            fullName.withCString { fullName in
                mpw_masterKey( fullName, masterPassword, .versionCurrent )
            }
        }),
           let authKeyID = mpw_id_buf( authKey, MPMasterKeySize ) {
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

    enum MPUserAvatar: Int {
        static let userAvatars = [
            MPUserAvatar.avatar_0, MPUserAvatar.avatar_1, MPUserAvatar.avatar_2, MPUserAvatar.avatar_3,
            MPUserAvatar.avatar_4, MPUserAvatar.avatar_5, MPUserAvatar.avatar_6, MPUserAvatar.avatar_7,
            MPUserAvatar.avatar_8, MPUserAvatar.avatar_9, MPUserAvatar.avatar_10, MPUserAvatar.avatar_11,
            MPUserAvatar.avatar_12, MPUserAvatar.avatar_13, MPUserAvatar.avatar_14, MPUserAvatar.avatar_15,
            MPUserAvatar.avatar_16, MPUserAvatar.avatar_17, MPUserAvatar.avatar_18 ]

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
