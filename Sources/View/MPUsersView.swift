//
// Created by Maarten Billemont on 2018-03-04.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class MPUsersView: UIView, MPSpinnerDelegate {

    let namesSpinner   = MPSpinnerView()
    let avatarsSpinner = MPSpinnerView()
    let nameLabel      = UILabel()
    var users          = [ MPUser ]() {
        willSet {
            for user in self.users {
                for subview in self.avatarsSpinner.subviews {
                    if let avatarView = subview as? MPUserAvatarView, user === avatarView.user {
                        avatarView.removeFromSuperview()
                    }
                }
                for subview in self.namesSpinner.subviews {
                    if let avatarView = subview as? MPUserNameView, user === avatarView.user {
                        avatarView.removeFromSuperview()
                    }
                }
            }
        }
        didSet {
            for user in self.users {
                self.avatarsSpinner.addSubview( MPUserAvatarView( user: user ) )
                self.namesSpinner.addSubview( MPUserNameView( user: user ) )
            }
        }
    }

    override init(frame: CGRect) {
        super.init( frame: frame )

        self.addSubview( self.namesSpinner )
        self.namesSpinner.addSubview( MPUserNameView( user: nil ) )
        self.namesSpinner.setAlignmentRectOutsets( UIEdgeInsets( top: -60, left: 0, bottom: 0, right: 0 ) )
        self.namesSpinner.isUserInteractionEnabled = false

        self.addSubview( self.avatarsSpinner )
        self.avatarsSpinner.addSubview( MPUserAvatarView( user: nil ) )
        self.avatarsSpinner.delegate = self

        self.avatarsSpinner.setFrameFrom( "|[]|" )
        self.namesSpinner.setFrameFrom( "|>[]<|" )

        defer {
            self.users = [ MPUser( named: "Maarten Billemont", avatar: .avatar_3 ),
                           MPUser( named: "Robert Lee Mitchell", avatar: .avatar_5 ) ]
            self.avatarsSpinner.selectedItem = self.avatarsSpinner.items - 1
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
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
            fatalError( "init(coder:) is not supported for this class" )
        }
    }

    class MPUserNameView: UILabel {
        var user: MPUser? {
            didSet {
                self.text = self.user?.name ?? "Tap to create a new user"
            }
        }

        init(user: MPUser?) {
            super.init( frame: CGRect() )

            self.font = UIFont( name: "Exo2.0-Regular", size: UIFont.labelFontSize )
            self.textAlignment = .center
            self.textColor = .white

            defer {
                self.user = user
            }
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }
    }

    func spinner(_ spinner: MPSpinnerView, didScanItem scannedItem: CGFloat) {
        self.namesSpinner.scan( toItem: scannedItem, animated: false )
    }

    func spinner(_ spinner: MPSpinnerView, didSelectItem selectedItem: Int?) {
    }
}
