//
// Created by Maarten Billemont on 2018-03-04.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit
import pop

class MPLoginView: UIView, MPSpinnerDelegate {

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

        public var active: Bool = false {
            didSet {
                let anim = POPSpringAnimation( sizeOfFontAtKeyPath: "font", on: UILabel.self )
                anim.toValue = UIFont.labelFontSize * (self.active ? 2: 1)
                self.nameLabel.pop_add( anim, forKey: "pop.font" )

                if self.active {
                    self.passwordField.becomeFirstResponder()
                }
                else {
                    self.passwordField.resignFirstResponder()
                }

                UIView.animate( withDuration: 0.3 ) {
                    self.passwordField.alpha = self.active ? 1: 0
                    self.idBadgeView.alpha = self.active ? 1: 0
                    self.authBadgeView.alpha = self.active ? 1: 0
                }
            }
        }
        public var user: MPUser? {
            didSet {
                self.avatarView.image = (self.user?.avatar ?? MPUser.MPUserAvatar.avatar_add).image()
                self.nameLabel.text = self.user?.name ?? "Tap to create a new user"
            }
        }

        private let nameLabel     = UILabel()
        private let avatarView    = UIImageView()
        private let passwordField = UITextField()
        private let idBadgeView   = UIImageView( image: UIImage( named: "icon_person" ) )
        private let authBadgeView = UIImageView( image: UIImage( named: "icon_key" ) )
        private var path          = CGMutablePath()

        init(user: MPUser?) {
            super.init( frame: CGRect() )

            defer {
                self.isOpaque = false
                self.layoutMargins = UIEdgeInsets( top: 20, left: 20, bottom: 20, right: 20 )

                self.nameLabel.font = UIFont( name: "Exo2.0-Regular", size: UIFont.labelFontSize )
                self.nameLabel.textAlignment = .center
                self.nameLabel.textColor = .white
                self.nameLabel.numberOfLines = 0
                self.nameLabel.setAlignmentRectOutsets( UIEdgeInsets( top: 0, left: 8, bottom: 0, right: 8 ) )

                self.avatarView.contentMode = .center

                self.passwordField.placeholder = "Enter your master password"
                self.passwordField.borderStyle = .roundedRect
                self.passwordField.font = UIFont( name: "SourceCodePro-Regular", size: UIFont.systemFontSize )
                self.passwordField.textAlignment = .center
                self.passwordField.setAlignmentRectOutsets( UIEdgeInsets( top: 0, left: 8, bottom: 0, right: 8 ) )

                self.idBadgeView.setAlignmentRectOutsets( UIEdgeInsets( top: 0, left: 8, bottom: 0, right: 0 ) )
                self.authBadgeView.setAlignmentRectOutsets( UIEdgeInsets( top: 0, left: 0, bottom: 0, right: 8 ) )

                self.addSubview( self.nameLabel )
                self.addSubview( self.avatarView )
                self.addSubview( self.passwordField )
                self.addSubview( self.idBadgeView )
                self.addSubview( self.authBadgeView )

                self.nameLabel.translatesAutoresizingMaskIntoConstraints = false
                self.nameLabel.topAnchor.constraint( equalTo: self.layoutMarginsGuide.topAnchor ).isActive = true
                self.nameLabel.leadingAnchor.constraint( equalTo: self.layoutMarginsGuide.leadingAnchor ).isActive = true
                self.nameLabel.trailingAnchor.constraint( equalTo: self.layoutMarginsGuide.trailingAnchor ).isActive = true
                self.nameLabel.bottomAnchor.constraint( equalTo: self.avatarView.topAnchor, constant: -20 ).isActive = true
                self.avatarView.translatesAutoresizingMaskIntoConstraints = false
                self.avatarView.centerXAnchor.constraint( equalTo: self.layoutMarginsGuide.centerXAnchor ).isActive = true
                self.passwordField.translatesAutoresizingMaskIntoConstraints = false
                self.passwordField.topAnchor.constraint( equalTo: self.avatarView.bottomAnchor, constant: 20 ).isActive = true
                self.passwordField.leadingAnchor.constraint( equalTo: self.layoutMarginsGuide.leadingAnchor ).isActive = true
                self.passwordField.trailingAnchor.constraint( equalTo: self.layoutMarginsGuide.trailingAnchor ).isActive = true
                self.passwordField.bottomAnchor.constraint( equalTo: self.layoutMarginsGuide.bottomAnchor ).isActive = true
                self.idBadgeView.translatesAutoresizingMaskIntoConstraints = false
                self.idBadgeView.trailingAnchor.constraint( equalTo: self.avatarView.leadingAnchor ).isActive = true;
                self.idBadgeView.centerYAnchor.constraint( equalTo: self.avatarView.centerYAnchor ).isActive = true;
                self.authBadgeView.translatesAutoresizingMaskIntoConstraints = false
                self.authBadgeView.leadingAnchor.constraint( equalTo: self.avatarView.trailingAnchor ).isActive = true;
                self.authBadgeView.centerYAnchor.constraint( equalTo: self.avatarView.centerYAnchor ).isActive = true;

                self.user = user
                self.active = false;
            }
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
            return super.systemLayoutSizeFitting( targetSize )
        }

        override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
            return super.systemLayoutSizeFitting( targetSize, withHorizontalFittingPriority: horizontalFittingPriority, verticalFittingPriority: verticalFittingPriority )
        }

        override func layoutSubviews() {
            super.layoutSubviews()

            path = CGMutablePath()
            path.addPath( CGPathCreateBetween( self.idBadgeView.alignmentRect, self.nameLabel.alignmentRect ) )
            path.addPath( CGPathCreateBetween( self.authBadgeView.alignmentRect, self.passwordField.alignmentRect ) )
            self.setNeedsDisplay()
        }

        override func draw(_ rect: CGRect) {
            super.draw( rect )

            if self.active, let context = UIGraphicsGetCurrentContext() {
                UIColor.white.withAlphaComponent( 0.8 ).setStroke()
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
