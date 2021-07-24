//==============================================================================
// Created by Maarten Billemont on 2018-10-15.
// Copyright (c) 2018 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
//==============================================================================

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

    func didChange(user: User, at change: PartialKeyPath<User>) {
        self.setNeedsUpdate()
    }

    // MARK: --- Types ---

    class IdenticonItem: LabelItem<User> {
        init() {
            super.init( value: { $0.identicon.attributedText() }, caption: { "\($0.userName)" } )
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
            view.valueField.leftViewMode = .always
            view.valueField.leftView = MarginView( for: UIImageView( image: .icon( "" ) ), margins: .border( 4 ) )
            return view
        }

        override func doUpdate() {
            super.doUpdate()

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
                        caption: {
                            """
                            Yearly budget of the primary attacker persona you're seeking to repel (@ \($0.attacker?.rig.cost_per_kwh)$/kWh).
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
                ToggleItem<User>( track: .subject( "user", action: "maskPasswords" ), title: "Mask Passwords",
                                  icon: { .icon( $0.maskPasswords ? "" : "👁" ) },
                                  value: { $0.maskPasswords }, update: { $0.model?.maskPasswords = $1 }, caption: { _ in
                    """
                    Do not reveal passwords on screen.
                    Useful to deter screen snooping.
                    """
                } ),
                ToggleItem( track: .subject( "user", action: "biometricLock" ), title: "Biometric Lock 🅿︎",
                            icon: { _ in .icon( KeychainKeyFactory.factor.icon ?? KeychainKeyFactory.Factor.biometricTouch.icon ) },
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

    class SystemFeaturesItem: Item<User> {
        init() {
            super.init( subitems: [
                ToggleItem<User>( track: .subject( "user", action: "autofill" ), title: "AutoFill 🅿︎", icon: { _ in .icon( "⌨" ) },
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
                ToggleItem<User>( track: .subject( "user", action: "sharing" ), title: "File Sharing", icon: { _ in .icon( "" ) },
                                  value: { $0.sharing }, update: { $0.model?.sharing = $1 }, caption: { _ in
                    """
                    Allow other apps to see and backup your user through On My iPhone.
                    """
                } )
            ] )
        }
    }

    class ActionsItem: Item<User> {
        init() {
            super.init( subitems: [
                ButtonItem( track: .subject( "user", action: "export" ), value: { _ in (label: "Export", image: nil) }, action: { item in
                    if let user = item.model {
                        let exportController = ExportViewController( user: user )
                        exportController.popoverPresentationController?.sourceView = item.view
                        exportController.popoverPresentationController?.sourceRect = item.view.bounds
                        item.viewController?.present( exportController, animated: true )
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

            addBehaviour( BlockTapBehaviour { item in
                guard let user = item.model, let viewController = item.viewController
                else { return }

                let alertController = UIAlertController( title: "User Algorithm", message:
                """
                New protections roll out in new algorithm versions. Always use the latest algorithm to protect your sites.

                \(user.algorithm == .current ?
                        "\(user.userName) is using the latest algorithm.":
                        "!! \(user.userName) is NOT using the latest algorithm. !!")
                """, preferredStyle: .actionSheet )
                alertController.popoverPresentationController?.sourceView = item.view
                alertController.popoverPresentationController?.sourceRect = item.view.bounds
                if user.algorithm < .last {
                    let upgrade = user.algorithm.advanced( by: 1 )
                    alertController.addAction( UIAlertAction( title: "Upgrade to \(upgrade.localizedDescription)", style: .default ) { _ in
                        user.userKeyFactory?.newKey( for: upgrade ).or(
                                    UIAlertController.authenticate(
                                            userName: user.userName, title: "Upgrade", message: "Your personal secret is required to perform the upgrade.",
                                            in: viewController, action: "Authenticate", authenticator: { $0.newKey( for: upgrade ) } ) )
                            .success { upgradedKey in
                                defer { upgradedKey.deallocate() }
                                user.algorithm = upgradedKey.pointee.algorithm
                                user.userKeyID = upgradedKey.pointee.keyID
                            }
                    } )
                }
                if user.algorithm > .first {
                    let downgrade = user.algorithm.advanced( by: -1 )
                    alertController.addAction( UIAlertAction( title: "Downgrade to \(downgrade.localizedDescription)", style: .default ) { _ in
                        user.userKeyFactory?.newKey( for: downgrade ).or(
                                    UIAlertController.authenticate(
                                            userName: user.userName, title: "Downgrade", message: "Your personal secret is required to perform the downgrade.",
                                            in: viewController, action: "Authenticate", authenticator: { $0.newKey( for: downgrade ) } ) )
                            .success { downgradedKey in
                                defer { downgradedKey.deallocate() }
                                user.algorithm = downgradedKey.pointee.algorithm
                                user.userKeyID = downgradedKey.pointee.keyID
                            }
                    } )
                }
                alertController.addAction( UIAlertAction( title: "Cancel", style: .cancel ) )
                viewController.present( alertController, animated: true )
            } )
        }

        override func doUpdate() {
            super.doUpdate()

            if let itemView = self.view as? LabelItemView {
                if self.model?.algorithm == .current {
                    itemView.valueLabel => \.textColor => Theme.current.color.body
                }
                else {
                    (itemView.valueLabel => \.textColor).unbind()
                    itemView.valueLabel.textColor = .systemRed
                }
            }
        }
    }

    class IdentifierItem: Item<User> {
        init() {
            super.init( title: "Private User Identifier",
                        caption: { (try? $0.authenticatedIdentifier.await()).flatMap { "\($0)" } } )

            self.addBehaviour( BlockTapBehaviour() {
                _ = $0.model.flatMap {
                    $0.userKeyFactory?.authenticatedIdentifier( for: $0.algorithm ).promise {
                        UIPasteboard.general.setItems(
                                [ [ UIPasteboard.typeAutomatic: $0 ?? "" ] ],
                                options: [
                                    UIPasteboard.OptionsKey.localOnly: !AppConfig.shared.allowHandoff
                                ] )
                    }
                }
            } )
        }
    }
}
