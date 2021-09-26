// =============================================================================
// Created by Maarten Billemont on 2018-10-15.
// Copyright (c) 2018 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import Foundation
import UIKit
import AuthenticationServices

class IntroAutoFillViewController: ItemsViewController<User>, DetailViewController, UserObserver {
    var isCloseHidden: Bool = true

    var autoFillState: ASCredentialIdentityStoreState? {
        didSet {
            if oldValue != self.autoFillState {
                self.setNeedsUpdate()
            }
        }
    }

    // MARK: - Life

    override func loadItems() -> [Item<User>] {
        [ ImageItem( title: "AutoFill 🅿︎", value: { _ in .icon( "keyboard", withSize: 64 ) },
                     caption: { _ in
                         """
                         Getting ready to use AutoFill on your \(UIDevice.current.model).
                         """
                     } ),
            SeparatorItem(),
            PagerItem( value: { [unowned self] _ in
                [
                    // Step 0
                    Item( subitems: [
                        Item( title: "Turning On AutoFill", caption: { _ in
                            """
                            To get AutoFill working smoothly on your \(UIDevice.current.model), there are a few things we need to get done.\n
                            Swipe ahead to begin.
                            """
                        } ),
                        ImageItem( value: { _ in .icon( "hand-point-right", withSize: 64 ) } ),
                    ], axis: .vertical ),

                    // Step 1
                    Item( subitems: [
                        Item( title: "Biometric Lock 🅿︎", caption: { _ in
                            """
                            \(KeychainKeyFactory.factor) is the quickest way to unlock your passwords.
                            """
                        } ),
                        ToggleItem( track: .subject( "autofill_setup", action: "biometricLock" ),
                                    icon: { _ in .icon( KeychainKeyFactory.factor.iconName ?? KeychainKeyFactory.Factor.biometricTouch.iconName ) },
                                    value: { $0.biometricLock }, update: { $0.model?.biometricLock = $1 } )
                                .addBehaviour( ColorizeBehaviour( color: .systemGreen ) { $0.biometricLock } )
                                .addBehaviour( PremiumTapBehaviour() )
                                .addBehaviour( PremiumConditionalBehaviour( effect: .enables ) ),
                    ], axis: .vertical ),

                    // Step 2
                    Item( subitems: [
                        Item( title: "Standard Login", caption: { _ in
                            """
                            Set the login name you use for most sites.
                            Select ⦗\(SpectreResultType.statePersonal.abbreviation)⦘ to save your e‑mail address.
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
                        ToggleItem( track: .subject( "autofill_setup", action: "settings" ),
                                    icon: { [unowned self] _ in (self.autoFillState?.isEnabled ?? false) ? .icon( "toggle-on" ): .icon( "toggle-off" ) },
                                    value: { [unowned self] _ in self.autoFillState?.isEnabled ?? false }, update: { _, _ in
                            URL( string: UIApplication.openSettingsURLString ).flatMap { UIApplication.shared.open( $0 ) }
                        } )
                                .addBehaviour( ColorizeBehaviour( color: .systemGreen ) { [unowned self] _ in
                                    self.autoFillState?.isEnabled ?? false
                                } ),
                    ], axis: .vertical ),

                    // Step 4
                    Item( subitems: [
                        Item( title: "AutoFill 🅿︎", caption: {
                            """
                            Enable auto-filling \($0.userName)'s sites from other apps.
                            """
                        } ),
                        ToggleItem<User>( track: .subject( "autofill_setup", action: "autofill" ), icon: { _ in .icon( "keyboard" ) },
                                          value: { $0.autofill }, update: { $0.model?.autofill = $1 } )
                                .addBehaviour( ColorizeBehaviour( color: .systemGreen ) { $0.autofill } )
                                .addBehaviour( PremiumTapBehaviour() )
                                .addBehaviour( PremiumConditionalBehaviour( effect: .enables ) ),
                    ], axis: .vertical ),
                ]
            } ),
        ]
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override init(model: User, focus: Item<User>.Type? = nil) {
        super.init( model: model, focus: focus )

        ASCredentialIdentityStore.shared.getState { self.autoFillState = $0 }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear( animated )

        self.model.observers.register( observer: self )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear( animated )

        self.model.observers.unregister( observer: self )
    }

    override func willEnterForeground() {
        super.willEnterForeground()

        ASCredentialIdentityStore.shared.getState { self.autoFillState = $0 }
    }

    // MARK: - UserObserver

    func didChange(user: User, at change: PartialKeyPath<User>) {
        self.setNeedsUpdate()
    }

    // MARK: - SiteObserver

    func siteDidChange(_ site: Site, at change: PartialKeyPath<Site>) {
        if change == \Site.preview {
            self.setNeedsUpdate()
        }
    }

    // MARK: - Updatable

    override func doUpdate() {
        super.doUpdate()

        if self.autoFillState?.isEnabled ?? false && self.model.autofill {
            self.hide {
                AlertController( title: "AutoFill Enabled",
                                 message: "\(self.model.userName)'s sites are now available from AutoFill." )
                        .show()
            }
        }
    }

    // MARK: - Types

    class LoginTypeItem: PickerItem<User, SpectreResultType, EffectResultTypeCell> {
        init() {
            super.init( track: .subject( "autofill_setup", action: "loginType" ),
                        values: { _ in
                            [ SpectreResultType? ].joined(
                                    separator: [ nil ],
                                    SpectreResultType.recommendedTypes[.identification],
                                    [ .statePersonal ],
                                    SpectreResultType.allCases.filter { !$0.has( feature: .alternate ) } ).unique()
                        },
                        value: { $0.loginType }, update: { $0.model?.loginType = $1 } )
        }

        override func populate(_ cell: EffectResultTypeCell, indexPath: IndexPath, value: SpectreResultType) {
            cell.resultType = value
        }
    }

    class LoginResultItem: FieldItem<User> {
        init() {
            super.init( title: nil, placeholder: "enter a login name",
                        value: { try? $0.result( keyPurpose: .identification )?.token.await() },
                        update: { item, login in
                            guard let user = item.model
                            else { return }

                            Tracker.shared.event( track: .subject( "autofill_setup", action: "login", [
                                "type": "\(user.loginType)",
                                "length": login.count,
                                "entropy": Attacker.entropy( string: login ),
                            ] ) )

                            user.state( keyPurpose: .identification, resultParam: login )?.token.then {
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

        override func doUpdate() {
            super.doUpdate()

            (self.view as? FieldItemView)?.valueField.isEnabled = self.model?.loginType.in( class: .stateful ) ?? false
        }
    }
}
