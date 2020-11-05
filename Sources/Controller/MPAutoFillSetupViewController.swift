//
// Created by Maarten Billemont on 2018-10-15.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation
import UIKit
import AuthenticationServices

class MPAutoFillSetupViewController: MPItemsViewController<MPUser>, MPDetailViewController, /*MPUserViewController*/MPUserObserver {
    var isCloseHidden:       Bool = true

    var autoFillState: ASCredentialIdentityStoreState? {
        didSet {
            if oldValue != self.autoFillState {
                self.setNeedsUpdate()
            }
        }
    }

    // MARK: --- Life ---

    override func loadItems() -> [Item<MPUser>] {
        [ ImageItem( title: "AutoFill Passwords", value: { _ in .icon( "", withSize: 64 ) },
                     caption: { _ in
                         """
                         Getting ready to use AutoFill on your \(UIDevice.current.model).
                         """
                     } ),
            SeparatorItem(),
            PagerItem( value: { _ in
                [
                    // Step 0
                    Item( subitems: [
                        Item( title: "Turning On AutoFill", caption: { _ in
                            """
                            To get AutoFill working smoothly on your \(UIDevice.current.model), there are a few things we need to get done.\n
                            Swipe ahead to begin.
                            """
                        } ),
                        ImageItem( value: { _ in .icon( "", withSize: 64 ) } ),
                    ], axis: .vertical ),

                    // Step 1
                    Item( subitems: [
                        Item( title: "Biometric Lock 🅿︎", caption: { _ in
                            """
                            \(MPKeychainKeyFactory.factor) is the quickest way to unlock your passwords.
                            """
                        } ),
                        ToggleItem( identifier: "user >biometricLock",
                                    icon: { _ in MPKeychainKeyFactory.factor.icon ?? MPKeychainKeyFactory.Factor.biometricTouch.icon },
                                    value: { $0.biometricLock }, update: { $0.biometricLock = $1 } )
                                //            MPKeychainKeyFactory.factor != .biometricNone
                                .addBehaviour( ColorizeBehaviour( color: .systemGreen ) { $0.biometricLock } )
                                .addBehaviour( PremiumTapBehaviour() )
                                .addBehaviour( PremiumConditionalBehaviour( mode: .enables ) )
                    ], axis: .vertical ),

                    // Step 2
                    Item( subitems: [
                        Item( title: "Standard Login", caption: { _ in
                            """
                            Set the login name you use for most services.
                            Select ⦗\(MPResultType.statefulPersonal.abbreviation)⦘ to save your e‑mail address.
                            """
                        } ),
                        LoginTypeItem(), LoginResultItem()
                                .addBehaviour( ColorizeBehaviour( color: .systemGreen ) { _ in true } ),
                    ], axis: .vertical ),

                    // Step 3
                    Item( subitems: [
                        Item( title: "AutoFill in Settings", caption: { _ in
                            """
                            ① Open Settings ❯ Passwords
                            ② Turn on ⦗AutoFill Passwords⦘ for ⦗\(productName)⦘
                            """
                        } ),
                        ToggleItem( identifier: "autofill >enable",
                                    icon: { _ in (self.autoFillState?.isEnabled ?? false) ? .icon( "" ): .icon( "" ) },
                                    value: { _ in self.autoFillState?.isEnabled ?? false }, update: { _, _ in
                            URL( string: UIApplication.openSettingsURLString ).flatMap { UIApplication.shared.open( $0 ) }
                        } )
                                .addBehaviour( ColorizeBehaviour( color: .systemGreen ) { _ in self.autoFillState?.isEnabled ?? false } )
                    ], axis: .vertical ),

                    // Step 4
                    Item( subitems: [
                        Item( title: "AutoFill Passwords 🅿︎", caption: {
                            """
                            Enable auto-filling \($0.fullName)'s services from other apps.
                            """
                        } ),
                        ToggleItem<MPUser>( identifier: "user >autofill", icon: { _ in .icon( "" ) },
                                            value: { $0.autofill }, update: { $0.autofill = $1 } )
                                .addBehaviour( ColorizeBehaviour( color: .systemGreen ) { $0.autofill } )
                                .addBehaviour( PremiumTapBehaviour() )
                                .addBehaviour( PremiumConditionalBehaviour( mode: .enables ) )
                    ], axis: .vertical ),
                ]
            } ),
        ]
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override init(model: MPUser, focus: Item<MPUser>.Type? = nil) {
        super.init( model: model, focus: focus )

        self.model.observers.register( observer: self ).userDidChange( self.model )
        ASCredentialIdentityStore.shared.getState { self.autoFillState = $0 }
    }

    override func willEnterForeground() {
        super.willEnterForeground()

        ASCredentialIdentityStore.shared.getState { self.autoFillState = $0 }
    }

    // MARK: --- MPUserObserver ---

    func userDidChange(_ user: MPUser) {
        self.setNeedsUpdate()
    }

    // MARK: --- Updatable ---

    override func update() {
        super.update()

        if self.autoFillState?.isEnabled ?? false && self.model.autofill {
            self.hide {
                MPAlert( title: "AutoFill Enabled", message: "\(self.model.fullName)'s services are now available from AutoFill." )
                        .show()
            }
        }
    }

    // MARK: --- Types ---

    class LoginTypeItem: PickerItem<MPUser, MPResultType, MPResultTypeCell> {
        init() {
            super.init( identifier: "user >loginType",
                        values: { _ in
                            [ MPResultType? ].joined(
                                    separator: [ nil ],
                                    MPResultType.recommendedTypes[.identification],
                                    [ MPResultType.statefulPersonal ],
                                    MPResultType.allCases.filter { !$0.has( feature: .alternative ) } ).unique()
                        },
                        value: { $0.loginType }, update: { $0.loginType = $1 } )
        }

        override func populate(_ cell: MPResultTypeCell, indexPath: IndexPath, value: MPResultType) {
            cell.resultType = value
        }
    }

    class LoginResultItem: FieldItem<MPUser> {
        init() {
            super.init( title: nil, placeholder: "enter a login name",
                        value: { try? $0.result( keyPurpose: .identification ).token.await() },
                        update: { user, login in
                            MPTracker.shared.event( named: "user >login", [
                                "type": "\(user.loginType)",
                                "entropy": MPAttacker.entropy( string: login ) ?? 0,
                            ] )

                            user.state( keyPurpose: .identification, resultParam: login ).token.then {
                                do { user.loginState = try $0.get() }
                                catch { mperror( title: "Couldn't update login name", error: error ) }
                            }
                        } )
        }

        override func createItemView() -> FieldItemView {
            let view = super.createItemView()
            view.valueField => \.font => Theme.current.font.password
            view.valueField.autocapitalizationType = .none
            view.valueField.autocorrectionType = .no
            view.valueField.keyboardType = .emailAddress
            return view
        }

        override func update() {
            super.update()

            (self.view as? FieldItemView)?.valueField.isEnabled = self.model?.loginType.in( class: .stateful ) ?? false
        }
    }
}
