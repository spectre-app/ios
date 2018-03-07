//
// Created by Maarten Billemont on 2018-03-04.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class MPUsersView: UIView, MPSpinnerDelegate {

    let usersSpinner = MPSpinnerView()
    let nameLabel    = UILabel()
    var users        = [ MPUser ]() {
        willSet {
            for user in self.users {
                for subview in self.usersSpinner.subviews {
                    if let avatarView = subview as? MPUserView, user === avatarView.user {
                        avatarView.removeFromSuperview()
                    }
                }
            }
        }
        didSet {
            for user in self.users {
                self.usersSpinner.addSubview( MPUserView( user: user ) )
            }
        }
    }

    override init(frame: CGRect) {
        super.init( frame: frame )

        self.addSubview( self.usersSpinner )
        self.usersSpinner.addSubview( MPUserView( user: nil ) )
        self.usersSpinner.delegate = self

        self.usersSpinner.setFrameFrom( "|[]|" )

        defer {
            self.users = [ MPUser( named: "Maarten Billemont", avatar: .avatar_3 ),
                           MPUser( named: "Robert Lee Mitchell", avatar: .avatar_5 ) ]
            self.usersSpinner.selectedItem = self.usersSpinner.items - 1
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    class MPUserView: UIView {

        public var active = false {
            didSet {
                self.setNeedsLayout()
                self.setNeedsDisplay()
            }
        }
        public var user: MPUser? {
            didSet {
                self.avatarView.image = (self.user?.avatar ?? MPUser.MPUserAvatar.avatar_add).image()
                self.nameLabel.text = self.user?.name ?? "Tap to create a new user"
            }
        }

        private let avatarView = UIImageView()
        private let nameLabel  = UILabel()
        private var path       = CGMutablePath()

        init(user: MPUser?) {
            super.init( frame: CGRect() )

            defer {
                self.isOpaque = false

                self.addSubview( self.avatarView )
                self.addSubview( self.nameLabel )

                self.avatarView.contentMode = .center

                self.nameLabel.setAlignmentRectOutsets( UIEdgeInsets( top: 0, left: 0, bottom: 4, right: 0 ) )
                self.nameLabel.font = UIFont( name: "Exo2.0-Regular", size: UIFont.labelFontSize )
                self.nameLabel.textAlignment = .center
                self.nameLabel.textColor = .white

                self.user = user
            }
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override func layoutSubviews() {
            super.layoutSubviews()

            self.nameLabel.font = self.nameLabel.font.withSize( UIFont.labelFontSize * (self.active ? 2: 1) )

            self.nameLabel.setFrameFrom( "|[]<|" )
            self.avatarView.setFrameFrom( "|x-[]|", x: self.nameLabel.alignmentAnchors.bottom )

            path = CGMutablePath()
            path.move( to: CGRectGetCenter( self.bounds ) )
            path.addLine( to: CGRectGetBottom( self.nameLabel.alignmentRect ) )
            path.move( to: CGRectGetBottomLeft( self.nameLabel.alignmentRect ) )
            path.addLine( to: CGRectGetBottomRight( self.nameLabel.alignmentRect ) )
        }

        override func draw(_ rect: CGRect) {
            super.draw( rect )

            if self.active, let context = UIGraphicsGetCurrentContext() {
                self.tintColor.setStroke()
                context.addPath( path )
                context.strokePath()
            }
        }
    }

    func spinner(_ spinner: MPSpinnerView, didScanItem scannedItem: CGFloat) {
    }

    func spinner(_ spinner: MPSpinnerView, didSelectItem selectedItem: Int?) {
    }

    func spinner(_ spinner: MPSpinnerView, didActivateItem activatedItem: Int) {
        if let userView = spinner.subviews[activatedItem] as? MPUserView {
            userView.active = true
        }
    }

    func spinner(_ spinner: MPSpinnerView, didDeactivateItem deactivatedItem: Int) {
        if let userView = spinner.subviews[deactivatedItem] as? MPUserView {
            userView.active = false
        }
    }
}
