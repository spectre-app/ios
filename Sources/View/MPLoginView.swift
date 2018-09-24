//
// Created by Maarten Billemont on 2018-03-04.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit
import pop

class MPLoginView: UIView, MPSpinnerDelegate {
    var users = [ MPUser ]() {
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

            self.usersSpinner.selectedItem = self.usersSpinner.items - 1
        }
    }

    let usersSpinner = MPSpinnerView()
    let nameLabel    = UILabel()

    // MARK: - Life

    override init(frame: CGRect) {
        super.init( frame: frame )

        self.addSubview( self.usersSpinner )
        self.usersSpinner.addSubview( MPUserView( user: nil ) )
        self.usersSpinner.delegate = self

        self.usersSpinner.setFrameFrom( "|[]|" )
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    // MARK: - MPSpinnerDelegate

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

    class MPUserView: UIView, UITextFieldDelegate {

        public var active: Bool = false {
            didSet {
                let anim = POPSpringAnimation( sizeOfFontAtKeyPath: "font", on: UILabel.self )
                anim.toValue = UIFont.labelFontSize * (self.active ? 2: 1)
                self.nameLabel.pop_add( anim, forKey: "pop.font" )

                UIView.animate( withDuration: self.superview == nil ? 0.0: 0.6 ) {
                    self.passwordField.alpha = self.active ? 1: 0

                    if self.active {
                        self.passwordConfiguration.activate()
                    }
                    else {
                        self.passwordConfiguration.deactivate()
                    }
                }

                self.setNeedsDisplay()
            }
        }
        public var user: MPUser? {
            didSet {
                self.avatarView.image = (self.user?.avatar ?? MPUser.MPUserAvatar.avatar_add).image()
                self.nameLabel.text = self.user?.fullName ?? "Tap to create a new user"
            }
        }

        private let nameLabel          = UILabel()
        private let avatarView         = UIImageView()
        private let passwordField      = UITextField()
        private let passwordIndicator  = UIActivityIndicatorView( activityIndicatorStyle: .gray )
        private let identiconLabel     = UILabel()
        private var identiconTimer:        Timer?
        private let identiconAccessory = UIInputView( frame: .zero, inputViewStyle: .default )
        private let idBadgeView        = UIImageView( image: UIImage( named: "icon_user" ) )
        private let authBadgeView      = UIImageView( image: UIImage( named: "icon_key" ) )
        private var passwordConfiguration: ViewConfiguration!
        private var path               = CGMutablePath()

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

                self.identiconLabel.font = UIFont( name: "SourceCodePro-Regular", size: UIFont.labelFontSize )
                self.identiconLabel.setAlignmentRectOutsets( UIEdgeInsets( top: 4, left: 4, bottom: 4, right: 4 ) )
                self.identiconLabel.shadowOffset = CGSize( width: 0, height: 1 )
                self.identiconLabel.shadowColor = .darkGray
                self.identiconLabel.textColor = .lightText

                self.identiconAccessory.allowsSelfSizing = true
                self.identiconAccessory.translatesAutoresizingMaskIntoConstraints = false
                self.identiconAccessory.addSubview( self.identiconLabel )
                ViewConfiguration( view: self.identiconLabel )
                        .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                        .constrainTo { $1.centerXAnchor.constraint( equalTo: $0.centerXAnchor ) }
                        .constrainTo { $1.leadingAnchor.constraint( greaterThanOrEqualTo: $0.leadingAnchor ) }
                        .constrainTo { $1.trailingAnchor.constraint( lessThanOrEqualTo: $0.trailingAnchor ) }
                        .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                        .activate()

                self.passwordField.placeholder = "Enter your master password"
                self.passwordField.borderStyle = .roundedRect
                self.passwordField.font = UIFont( name: "SourceCodePro-Regular", size: UIFont.systemFontSize )
                self.passwordField.textAlignment = .center
                self.passwordField.setAlignmentRectOutsets( UIEdgeInsets( top: 0, left: 8, bottom: 0, right: 8 ) )
                self.passwordField.inputAccessoryView = self.identiconAccessory;
                self.passwordField.isSecureTextEntry = true
                self.passwordField.delegate = self

                self.passwordIndicator.hidesWhenStopped = true
                self.passwordIndicator.frame = self.passwordIndicator.frame.insetBy( dx: -8, dy: 0 )
                self.passwordField.rightView = self.passwordIndicator
                self.passwordField.leftView = UIView( frame: self.passwordIndicator.frame )
                self.passwordField.leftViewMode = .always
                self.passwordField.rightViewMode = .always

                self.idBadgeView.setAlignmentRectOutsets( UIEdgeInsets( top: 0, left: 8, bottom: 0, right: 0 ) )
                self.authBadgeView.setAlignmentRectOutsets( UIEdgeInsets( top: 0, left: 0, bottom: 0, right: 8 ) )

                self.addSubview( self.idBadgeView )
                self.addSubview( self.authBadgeView )
                self.addSubview( self.avatarView )
                self.addSubview( self.nameLabel )
                self.addSubview( self.passwordField )

                ViewConfiguration( view: self.nameLabel )
                        .constrainTo { $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.topAnchor ) }
                        .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                        .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                        .constrainTo { $1.bottomAnchor.constraint( equalTo: self.avatarView.topAnchor, constant: -20 ) }
                        .activate()
                ViewConfiguration( view: self.avatarView )
                        .constrainTo { $1.centerXAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerXAnchor ) }
                        .activate()
                ViewConfiguration( view: self.passwordField )
                        .constrainTo { $1.topAnchor.constraint( equalTo: self.avatarView.bottomAnchor, constant: 20 ) }
                        .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                        .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                        .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.layoutMarginsGuide.bottomAnchor ) }
                        .activate()

                self.passwordConfiguration = ViewConfiguration( view: self.passwordField ) { active, inactive in
                    active.set( 1, forKey: "alpha" )
                    active.set( true, forKey: "enabled" )
                    active.becomeFirstResponder()
                    inactive.set( 0, forKey: "alpha" )
                    inactive.set( false, forKey: "enabled" )
                    inactive.set( nil, forKey: "text" )
                    inactive.resignFirstResponder()
                }
                        .apply( ViewConfiguration( view: self.idBadgeView ) { active, inactive in
                            active.constrainTo { $1.trailingAnchor.constraint( equalTo: self.avatarView.leadingAnchor ) }
                            active.constrainTo { $1.centerYAnchor.constraint( equalTo: self.avatarView.centerYAnchor ) }
                            active.set( 1, forKey: "alpha" )
                            inactive.constrainTo { $1.centerXAnchor.constraint( equalTo: self.avatarView.centerXAnchor ) }
                            inactive.constrainTo { $1.centerYAnchor.constraint( equalTo: self.avatarView.centerYAnchor ) }
                            inactive.set( 0, forKey: "alpha" )
                        } )
                        .apply( ViewConfiguration( view: self.authBadgeView ) { active, inactive in
                            active.constrainTo { $1.leadingAnchor.constraint( equalTo: self.avatarView.trailingAnchor ) }
                            active.constrainTo { $1.centerYAnchor.constraint( equalTo: self.avatarView.centerYAnchor ) }
                            active.set( 1, forKey: "alpha" )
                            inactive.constrainTo { $1.centerXAnchor.constraint( equalTo: self.avatarView.centerXAnchor ) }
                            inactive.constrainTo { $1.centerYAnchor.constraint( equalTo: self.avatarView.centerYAnchor ) }
                            inactive.set( 0, forKey: "alpha" )
                        } )
                        .needsLayout( self )

                self.user = user
                self.active = false;

                NotificationCenter.default.addObserver( forName: .UITextFieldTextDidChange, object: self.passwordField, queue: nil ) { notification in
                    self.setNeedsIdenticon()
                }
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
            if self.passwordConfiguration.activated {
                path.addPath( CGPathCreateBetween( self.idBadgeView.alignmentRect, self.nameLabel.alignmentRect ) )
                path.addPath( CGPathCreateBetween( self.authBadgeView.alignmentRect, self.passwordField.alignmentRect ) )
            }
            self.setNeedsDisplay()
        }

        override func draw(_ rect: CGRect) {
            super.draw( rect )

            if self.active, let context = UIGraphicsGetCurrentContext() {
                UIColor.white.withAlphaComponent( 0.618 ).setStroke()
                context.addPath( path )
                context.strokePath()
            }
        }

        override func willMove(toWindow newWindow: UIWindow?) {
            super.willMove( toWindow: newWindow )

            if newWindow == nil {
                self.identiconTimer?.invalidate()
            }
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if textField == self.passwordField {
                self.identiconLabel.text = nil
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if textField == self.passwordField {
                self.identiconLabel.text = nil
            }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            if textField == self.passwordField, let masterPassword = self.passwordField.text {
                guard masterPassword.count > 0
                else { return false }

                self.passwordIndicator.startAnimating()
                self.passwordField.isEnabled = false

                PearlNotMainQueue {
                    self.user!.authenticate( masterPassword: masterPassword )

                    PearlMainQueue {
                        self.passwordIndicator.stopAnimating()

                        UIView.animate( withDuration: 0.6 ) {
                            self.passwordConfiguration.deactivate()
                        }
                    }
                }
                return true
            }

            return true
        }

        func setNeedsIdenticon() {
            self.identiconTimer?.invalidate()
            self.identiconTimer = Timer.scheduledTimer(
                    timeInterval: 0.3 + drand48() * 0.2,
                    target: self, selector: #selector( MPUserView.updateIdenticon ),
                    userInfo: nil, repeats: false )
        }

        @objc
        func updateIdenticon() {
            if let userName = self.user?.fullName {
                userName.withCString { userName in
                    if let masterPassword = self.passwordField.text {
                        masterPassword.withCString { masterPassword in
                            let identicon = mpw_identicon( userName, masterPassword )
                            self.identiconLabel.text = [
                                String( cString: identicon.leftArm ),
                                String( cString: identicon.body ),
                                String( cString: identicon.rightArm ),
                                String( cString: identicon.accessory ) ].joined()
                            switch identicon.color {
                                case .red:
                                    self.identiconLabel.textColor = .red
                                case .green:
                                    self.identiconLabel.textColor = .green
                                case .yellow:
                                    self.identiconLabel.textColor = .yellow
                                case .blue:
                                    self.identiconLabel.textColor = .blue
                                case .magenta:
                                    self.identiconLabel.textColor = .magenta
                                case .cyan:
                                    self.identiconLabel.textColor = .cyan
                                case .white:
                                    self.identiconLabel.textColor = .white
                            }
                        }
                    }
                }
            }
        }
    }
}
