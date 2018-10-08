//
// Created by Maarten Billemont on 2018-03-04.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPUser {
    var observers = Observers<MPUserObserver>()

    let fullName: String
    var avatar: MPUserAvatar {
        didSet {
            self.observers.notify { $0.userDidChange() }
        }
    }

    var algorithm: MPAlgorithmVersion {
        didSet {
            self.observers.notify { $0.userDidChange() }
        }
    }
    var defaultType: MPResultType {
        didSet {
            self.observers.notify { $0.userDidChange() }
        }
    }

    var masterKeyID: MPKeyID? {
        didSet {
            self.observers.notify { $0.userDidChange() }
        }
    }
    var masterKey: MPMasterKey? {
        didSet {
            if let _ = self.masterKey {
                self.observers.notify { $0.userDidLogin() }
            }
            else {
                self.observers.notify { $0.userDidLogout() }
            }
        }
    }
    var sites = [ MPSite ]() {
        didSet {
            self.observers.notify { $0.userDidUpdateSites() }
        }
    }
    var sortedSites : [ MPSite ] {
        get {
            return self.sites.sorted()
        }
    }

    // MARK: - Life

    init(named name: String, avatar: MPUserAvatar = .avatar_0,
         algorithm: MPAlgorithmVersion? = nil, defaultType: MPResultType? = nil, masterKeyID: MPKeyID? = nil) {
        self.fullName = name
        self.avatar = avatar
        self.algorithm = algorithm ?? .versionCurrent
        self.defaultType = defaultType ?? .default
        self.masterKeyID = masterKeyID

        self.sites.append( MPSite( user: self, named: "apple.com", uses: 5, lastUsed: Date().addingTimeInterval( -1000 ) ) )
        self.sites.append( MPSite( user: self, named: "google.com", uses: 20, lastUsed: Date().addingTimeInterval( -2000 ) ) )
        self.sites.append( MPSite( user: self, named: "twitter.com", uses: 3, lastUsed: Date().addingTimeInterval( -5000 ) ) )
        self.sites.append( MPSite( user: self, named: "reddit.com", uses: 8, lastUsed: Date().addingTimeInterval( -10000 ) ) )
        self.sites.append( MPSite( user: self, named: "pinterest.com", uses: 7, lastUsed: Date().addingTimeInterval( -12000 ) ) )
        self.sites.append( MPSite( user: self, named: "whatsapp.com", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ) )
        self.sites.append( MPSite( user: self, named: "ivpn.net", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ) )
        self.sites.append( MPSite( user: self, named: "amazon.com", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ) )
        self.sites.append( MPSite( user: self, named: "matrix.org", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ) )
        self.sites.append( MPSite( user: self, named: "spotify.com", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ) )
        self.sites.append( MPSite( user: self, named: "netflix.com", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ) )
        self.sites.append( MPSite( user: self, named: "uber.com", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ) )
        self.sites.append( MPSite( user: self, named: "battle.net", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ) )
        self.sites.append( MPSite( user: self, named: "gandi.net", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ) )
        self.sites.append( MPSite( user: self, named: "ebay.com", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ) )
        self.sites.append( MPSite( user: self, named: "last.fm", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ) )

        PearlNotMainQueue {
            self.masterKey = mpw_masterKey( self.fullName, "test", self.algorithm )
        }
    }

    // MARK: - Interface

    func authenticate(masterPassword: String) {
        self.masterKey = masterPassword.withCString { masterPassword in
            fullName.withCString { fullName in
                mpw_masterKey( fullName, masterPassword, .versionCurrent )
            }
        }
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
    func userDidLogin()
    func userDidLogout()

    func userDidChange()
    func userDidUpdateSites()
}
