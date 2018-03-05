//
// Created by Maarten Billemont on 2018-03-04.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPUser {
    let name:   String
    var avatar: MPUserAvatar

    init(named name: String, avatar: MPUserAvatar = .avatar_0) {
        self.name = name;
        self.avatar = avatar;
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
