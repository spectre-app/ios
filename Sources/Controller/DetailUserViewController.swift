//
// Created by Maarten Billemont on 2018-10-15.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation
import UIKit

class DetailUserViewController: ItemsViewController<User>, UserObserver {

    // MARK: --- Life ---

    override func loadItems() -> [Item<User>] {
        [ IdenticonItem(), AvatarItem(), ActionsItem(), SeparatorItem(),
          LoginTypeItem(), DefaultTypeItem(), SeparatorItem(),
          AttackerItem(), SeparatorItem(),
          UsageFeaturesItem(), SystemFeaturesItem(), SeparatorItem(),
          InfoItem(), IdentifierItem(),
        ]
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override init(model: User, focus: Item<User>.Type? = nil) {
        super.init( model: model, focus: focus )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear( animated )

        self.model.observers.register( observer: self )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear( animated )

        self.model.observers.unregister( observer: self )
    }

    // MARK: --- UserObserver ---

    func userDidChange(_ user: User) {
        self.setNeedsUpdate()
    }

    // MARK: --- Types ---

    class IdenticonItem: LabelItem<User> {
        init() {
            super.init( value: { $0.identicon.attributedText() }, caption: { $0.userName } )
        }
    }

    class AvatarItem: PickerItem<User, User.Avatar, AvatarCell> {
        init() {
            super.init( track: .subject( "user", action: "avatar" ), title: "Avatar", values: { _ in User.Avatar.allCases },
                        value: { $0.avatar }, update: { $0.model?.avatar = $1 } )
        }

        override func populate(_ cell: AvatarCell, indexPath: IndexPath, value: User.Avatar) {
            cell.avatar = value
        }
    }

    class LoginTypeItem: PickerItem<User, SpectreResultType, EffectResultTypeCell> {
        init() {
            super.init( track: .subject( "user", action: "loginType" ), title: "Standard Login",
                        values: { _ in
                            [ SpectreResultType? ].joined(
                                    separator: [ nil ],
                                    SpectreResultType.recommendedTypes[.identification],
                                    [ .statePersonal ],
                                    SpectreResultType.allCases.filter { !$0.has( feature: .alternate ) } ).unique()
                        },
                        value: { $0.loginType }, update: { $0.model?.loginType = $1 },
                        subitems: [ LoginResultItem() ],
                        caption: { _ in
                            """
                            The login name used for sites that do not have a site‑specific login name. 
                            """
                        } )
        }

        override func populate(_ cell: EffectResultTypeCell, indexPath: IndexPath, value: SpectreResultType) {
            cell.resultType = value
        }
    }

    class LoginResultItem: FieldItem<User> {
        init() {
            super.init( title: nil, placeholder: "enter a login name",
                        value: { try? $0.result( keyPurpose: .identification ).token.await() },
                        update: { item, login in
                            guard let user = item.model
                            else { return }

                            Tracker.shared.event( track: .subject( "user", action: "login", [
                                "type": "\(user.loginType)",
                                "entropy": Attacker.entropy( string: login ) ?? 0,
                            ] ) )

                            user.state( keyPurpose: .identification, resultParam: login ).token.then {
                                do { user.loginState = try $0.get() }
                                catch { mperror( title: "Couldn't update login name", error: error ) }
                            }
                        } )

            self.addBehaviour( PremiumConditionalBehaviour( mode: .reveals ) )
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

    class DefaultTypeItem: PickerItem<User, SpectreResultType, EffectResultTypeCell> {
        init() {
            super.init( track: .subject( "user", action: "defaultType" ), title: "Default Password Type",
                        values: { _ in
                            [ SpectreResultType? ].joined(
                                    separator: [ nil ],
                                    SpectreResultType.recommendedTypes[.authentication],
                                    SpectreResultType.allCases.filter { !$0.has( feature: .alternate ) } ).unique()
                        },
                        value: { $0.defaultType }, update: { $0.model?.defaultType = $1 },
                        caption: { _ in
                            """
                            The password type used when adding new sites.
                            """
                        } )
        }

        override func populate(_ cell: EffectResultTypeCell, indexPath: IndexPath, value: SpectreResultType) {
            cell.resultType = value
        }
    }

    class AttackerItem: PickerItem<User, Attacker?, AttackerItem.Cell> {
        init() {
            super.init( track: .subject( "user", action: "attacker" ), title: "Defense Strategy 🅿︎", values: { _ in Attacker.allCases },
                        value: { $0.attacker ?? .default }, update: { $0.model?.attacker = $1 },
                        caption: { _ in
                            """
                            Yearly budget of the primary attacker persona you're seeking to repel (@ \(cost_per_kwh)$/kWh).
                            """
                        } )

            self.addBehaviour( PremiumTapBehaviour() )
            self.addBehaviour( PremiumConditionalBehaviour( mode: .enables ) )
        }

        override func populate(_ cell: Cell, indexPath: IndexPath, value: Attacker?) {
            cell.attacker = value
        }

        class Cell: EffectClassifiedCell {
            var attacker: Attacker? {
                didSet {
                    DispatchQueue.main.perform {
                        if let attacker = self.attacker {
                            self.name = "\(number: attacker.fixed_budget + attacker.monthly_budget * 12, decimals: 0...0, locale: .C, .currency, .abbreviated)"
                            self.class = "\(attacker)"
                        }
                        else {
                            self.name = "Off"
                            self.class = nil
                        }
                    }
                }
            }
        }
    }

    class UsageFeaturesItem: Item<User> {
        init() {
            super.init( subitems: [
                ToggleItem<User>( track: .subject( "user", action: "maskPasswords" ), title: "Mask Passwords", icon: { _ in .icon( "" ) },
                                  value: { $0.maskPasswords }, update: { $0.model?.maskPasswords = $1 }, caption: { _ in
                    """
                    Do not reveal passwords on screen.
                    Useful to deter screen snooping.
                    """
                } ),
            ] )
        }
    }

    class SystemFeaturesItem: Item<User> {
        init() {
            super.init( subitems: [
                ToggleItem<User>( track: .subject( "user", action: "autofill" ), title: "AutoFill 🅿︎", icon: { _ in .icon( "" ) },
                                  value: { $0.autofill }, update: { $0.model?.autofill = $1 }, caption: { _ in
                    """
                    Auto-fill your site passwords from other apps.
                    """
                } )
                        .addBehaviour( BlockTapBehaviour( enabled: { !($0.model?.autofillDecided ?? true) } ) {
                            if let user = $0.model {
                                $0.viewController?.show( IntroAutoFillViewController( model: user ), sender: $0.view )
                            }
                        } )
                        .addBehaviour( PremiumTapBehaviour() )
                        .addBehaviour( PremiumConditionalBehaviour( mode: .enables ) ),
                ToggleItem( track: .subject( "user", action: "biometricLock" ), title: "Biometric Lock 🅿︎",
                            icon: { _ in KeychainKeyFactory.factor.icon ?? KeychainKeyFactory.Factor.biometricTouch.icon },
                            value: { $0.biometricLock }, update: { $0.model?.biometricLock = $1 }, caption: { _ in
                    """
                    Sign in using biometrics (eg. TouchID, FaceID).
                    Saves your user key in the device's key chain.
                    """
                } )
                        // TODO: Enable toggle if premium is off but biometric key is set to allow clearing it?
                        .addBehaviour( PremiumTapBehaviour() )
                        .addBehaviour( PremiumConditionalBehaviour( mode: .enables ) ),
            ] )
        }
    }

    class ActionsItem: Item<User> {
        init() {
            super.init( subitems: [
                ButtonItem( track: .subject( "user", action: "export" ), value: { _ in (label: "Export", image: nil) }, action: { item in
                    if let user = item.model {
                        let controller = ExportViewController( user: user )
                        controller.popoverPresentationController?.sourceView = item.view
                        controller.popoverPresentationController?.sourceRect = item.view.bounds
                        item.viewController?.present( controller, animated: true )
                    }
                } ),
                ButtonItem( track: .subject( "user", action: "app" ), value: { _ in (label: "Settings", image: nil) }, action: { item in
                    item.viewController?.show( DetailAppViewController(), sender: item )
                } ),
                ButtonItem( track: .subject( "user", action: "signout" ), value: { _ in (label: "Log out", image: nil) }, action: { item in
                    item.model?.logout()
                } ),
            ] )
        }
    }

    class InfoItem: Item<User> {
        init() {
            super.init( title: nil, subitems: [
                UsesItem(),
                UsedItem(),
                AlgorithmItem(),
            ] )
        }
    }

    class UsesItem: LabelItem<User> {
        init() {
            super.init( title: "Sites", value: { $0.sites.count } )
        }
    }

    class UsedItem: DateItem<User> {
        init() {
            super.init( title: "Last Used", value: { $0.lastUsed } )
        }
    }

    class AlgorithmItem: LabelItem<User> {
        init() {
            super.init( title: "Algorithm", value: { $0.algorithm } )
        }
    }

    class IdentifierItem: Item<User> {
        init() {
            super.init( title: "Private User Identifier",
                        caption: { try? $0.authenticatedIdentifier.await() } )

            self.addBehaviour( BlockTapBehaviour() {
                _ = $0.model.flatMap {
                    $0.userKeyFactory?.authenticatedIdentifier( for: $0.algorithm ).promise {
                        UIPasteboard.general.setItems( [ [ UIPasteboard.typeAutomatic: $0 ?? "" ] ] )
                    }
                }
            } )
        }
    }
}
