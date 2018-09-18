//
// Created by Maarten Billemont on 2018-03-04.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPUser {
    let fullName:  String
    var avatar:    MPUserAvatar
    var masterKey: Data?
    var sites = [ MPSite ]()

    // MARK: - Life

    init(named name: String, avatar: MPUserAvatar = .avatar_0) {
        self.fullName = name
        self.avatar = avatar

        self.sites.append( MPSite( named: "apple.com", uses: 5, lastUsed: Date().addingTimeInterval( -1000 ) ) )
        self.sites.append( MPSite( named: "google.com", uses: 20, lastUsed: Date().addingTimeInterval( -2000 ) ) )
        self.sites.append( MPSite( named: "twitter.com", uses: 3, lastUsed: Date().addingTimeInterval( -5000 ) ) )
        self.sites.append( MPSite( named: "reddit.com", uses: 8, lastUsed: Date().addingTimeInterval( -10000 ) ) )
        self.sites.append( MPSite( named: "pinterest.com", uses: 7, lastUsed: Date().addingTimeInterval( -12000 ) ) )
        self.sites.append( MPSite( named: "whatsapp.com", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ) )
        self.sites.append( MPSite( named: "ivpn.net", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ) )
        self.sites.append( MPSite( named: "amazon.com", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ) )
        self.sites.append( MPSite( named: "matrix.org", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ) )
        self.sites.append( MPSite( named: "spotify.com", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ) )
        self.sites.append( MPSite( named: "netflix.com", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ) )
        self.sites.append( MPSite( named: "uber.com", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ) )
        self.sites.append( MPSite( named: "battle.net", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ) )
        self.sites.append( MPSite( named: "gandi.net", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ) )
        self.sites.append( MPSite( named: "ebay.com", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ) )
        self.sites.append( MPSite( named: "last.fm", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ) )
    }

    // MARK: - Interface

    func authenticate(masterPassword: String) {
        self.masterKey = masterPassword.withCString { masterPassword in
            fullName.withCString { fullName in
                Data( bytes: mpw_masterKey( fullName, masterPassword, .versionCurrent ), count: MPMasterKeySize )
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
