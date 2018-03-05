//
// Created by Maarten Billemont on 2018-03-04.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class MPUsersView: UIView {

    let avatarSpinner = MPSpinnerView()
    let newUserView   = MPUserAvatarView( user: nil )
    let nameLabel     = UILabel()
    var users         = [ MPUser ]() {
        willSet {
            for user in self.users {
                for subview in self.avatarSpinner.subviews {
                    if let avatarView = subview as? MPUserAvatarView, user === avatarView.user {
                        avatarView.removeFromSuperview()
                    }
                }
            }
        }
        didSet {
            for user in self.users {
                self.avatarSpinner.addSubview( MPUserAvatarView( user: user ) )
            }
        }
    }

    override init(frame: CGRect) {
        super.init( frame: frame )

        self.addSubview( self.avatarSpinner )
        self.avatarSpinner.addSubview( self.newUserView )
        self.avatarSpinner.setFrameFrom( "|[]|" )

        defer {
            self.users = [ MPUser( named: "Maarten Billemont", avatar: .avatar_3 ),
                           MPUser( named: "Robert Lee Mitchell", avatar: .avatar_5 ) ]
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init( coder: aDecoder )
    }

    class MPUserAvatarView: UIImageView {
        var user: MPUser? {
            didSet {
                self.image = (self.user?.avatar ?? MPUser.MPUserAvatar.avatar_add).image()
            }
        }

        init(user: MPUser?) {
            super.init( image: nil )

            defer {
                self.user = user
            }
        }

        required init?(coder aDecoder: NSCoder) {
            super.init( coder: aDecoder )
        }

        func set(user: MPUser?) {
            self.user = user
        }
    }
}
