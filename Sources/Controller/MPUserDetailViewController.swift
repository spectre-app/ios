//
// Created by Maarten Billemont on 2018-10-15.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation
import UIKit

class MPUserDetailsViewController: MPItemsViewController<MPUser>, /*MPUserViewController*/MPUserObserver, MPConfigObserver {

    // MARK: --- Life ---

    override func loadItems() -> [Item<MPUser>] {
        [ IdenticonItem(), AvatarItem(), ActionsItem(), SeparatorItem(),
          LoginTypeItem(), LoginResultItem(), DefaultTypeItem(), SeparatorItem(),
          AttackerItem(), SeparatorItem(),
          UsageFeaturesItem(), SystemFeaturesItem(), SeparatorItem(),
          InfoItem(),
        ]
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override init(model: MPUser, focus: Item<MPUser>.Type? = nil) {
        super.init( model: model, focus: focus )

        self.model.observers.register( observer: self ).userDidChange( self.model )
        appConfig.observers.register( observer: self )
    }

    // MARK: --- MPUserObserver ---

    func userDidChange(_ user: MPUser) {
        self.setNeedsUpdate()
    }

    // MARK: --- MPConfigObserver ---

    func didChangeConfig() {
        self.setNeedsUpdate()
    }

    // MARK: --- Types ---

    class IdenticonItem: LabelItem<MPUser> {
        init() {
            super.init( value: { $0.identicon.attributedText() }, caption: { $0.fullName } )
        }
    }

    class AvatarItem: PickerItem<MPUser, MPUser.Avatar> {
        init() {
            super.init( identifier: "user >avatar", title: "Avatar",
                        values: { _ in MPUser.Avatar.allCases },
                        value: { $0.avatar },
                        update: { $0.avatar = $1 } )
        }

        override func didLoad(collectionView: UICollectionView) {
            collectionView.register( MPAvatarCell.self )
        }

        override func cell(collectionView: UICollectionView, indexPath: IndexPath, model: MPUser, value: MPUser.Avatar) -> UICollectionViewCell? {
            MPAvatarCell.dequeue( from: collectionView, indexPath: indexPath ) {
                ($0 as? MPAvatarCell)?.avatar = value
            }
        }
    }

    class LoginTypeItem: PickerItem<MPUser, MPResultType> {
        init() {
            super.init( identifier: "user >loginType", title: "Standard Login",
                        values: { _ in
                            [ MPResultType? ].joined(
                                    separator: [ nil ],
                                    MPResultType.recommendedTypes[.identification],
                                    [ MPResultType.statefulPersonal ],
                                    MPResultType.allCases.filter { !$0.has( feature: .alternative ) } ).unique()
                        },
                        value: { $0.loginType },
                        update: { $0.loginType = $1 } )
        }

        override func didLoad(collectionView: UICollectionView) {
            collectionView.register( MPResultTypeCell.self )
        }

        override func cell(collectionView: UICollectionView, indexPath: IndexPath, model: MPUser, value: MPResultType) -> UICollectionViewCell? {
            MPResultTypeCell.dequeue( from: collectionView, indexPath: indexPath ) {
                ($0 as! MPResultTypeCell).resultType = value
            }
        }
    }

    class LoginResultItem: FieldItem<MPUser> {
        init() {
            super.init( title: nil, placeholder: "set a user name",
                        value: { try? $0.result( keyPurpose: .identification ).token.await() },
                        update: { user, login in
                            MPTracker.shared.event( named: "user >login", [
                                "type": "\(user.loginType)",
                                "entropy": MPAttacker.entropy( string: login ) ?? 0,
                            ] )

                            user.state( keyPurpose: .identification, resultParam: login ).token.then {
                                do { user.loginState = try $0.get() }
                                catch { mperror( title: "Couldn't update user name", error: error ) }
                            }
                        } )

            self.addBehaviour( PremiumConditionalBehaviour( mode: .reveals ) )
        }

        override func createItemView() -> FieldItemView<MPUser> {
            let view = super.createItemView()
            view.valueField => \.font => Theme.current.font.password
            view.valueField.autocapitalizationType = .none
            view.valueField.autocorrectionType = .no
            view.valueField.keyboardType = .emailAddress
            return view
        }

        override func update() {
            super.update()

            (self.view as? FieldItemView<MPUser>)?.valueField.isEnabled = self.model?.loginType.in( class: .stateful ) ?? false
        }
    }

    class DefaultTypeItem: PickerItem<MPUser, MPResultType> {
        init() {
            super.init( identifier: "user >defaultType", title: "Default Password Type",
                        values: { _ in
                            [ MPResultType? ].joined(
                                    separator: [ nil ],
                                    MPResultType.recommendedTypes[.authentication],
                                    MPResultType.allCases.filter { !$0.has( feature: .alternative ) } ).unique()
                        },
                        value: { $0.defaultType },
                        update: { $0.defaultType = $1 } )
        }

        override func didLoad(collectionView: UICollectionView) {
            collectionView.register( MPResultTypeCell.self )
        }

        override func cell(collectionView: UICollectionView, indexPath: IndexPath, model: MPUser, value: MPResultType) -> UICollectionViewCell? {
            MPResultTypeCell.dequeue( from: collectionView, indexPath: indexPath ) {
                ($0 as! MPResultTypeCell).resultType = value
            }
        }
    }

    class AttackerItem: PickerItem<MPUser, MPAttacker?> {
        init() {
            super.init( identifier: "user >attacker", title: "Defense Strategy 🅿︎",
                        values: { _ in MPAttacker.allCases },
                        value: { $0.attacker ?? .default },
                        update: { $0.attacker = $1 },
                        caption: { _ in
                            """
                            Yearly budget of the primary attacker persona you're seeking to repel (@ \(cost_per_kwh)$/kWh).
                            """
                        } )

            self.addBehaviour( PremiumTapBehaviour() )
            self.addBehaviour( PremiumConditionalBehaviour( mode: .enables ) )
        }

        override func didLoad(collectionView: UICollectionView) {
            collectionView.register( Cell.self )
        }

        override func cell(collectionView: UICollectionView, indexPath: IndexPath, model: MPUser, value: MPAttacker?) -> UICollectionViewCell? {
            Cell.dequeue( from: collectionView, indexPath: indexPath ) {
                ($0 as! Cell).attacker = value
            }
        }

        class Cell: MPClassItemCell {
            var attacker: MPAttacker? {
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

    class UsageFeaturesItem: Item<MPUser> {
        init() {
            super.init( subitems: [
                ToggleItem<MPUser>(
                        identifier: "user >maskPasswords",
                        title: "Mask Passwords",
                        value: {
                            (icon: .icon( "" ),
                             selected: $0.maskPasswords,
                             enabled: true)
                        },
                        update: { $0.maskPasswords = $1 },
                        caption: { _ in
                            """
                            Do not reveal passwords on screen.
                            Useful to deter screen snooping.
                            """
                        } ),
            ] )
        }
    }

    class SystemFeaturesItem: Item<MPUser> {
        init() {
            super.init( subitems: [
                ToggleItem<MPUser>(
                        identifier: "user >autofill",
                        title: "AutoFill Passwords 🅿︎",
                        value: {
                            (icon: .icon( "" ),
                             selected: $0.autofill,
                             enabled: true)
                        },
                        update: { $0.autofill = $1 },
                        caption: { _ in
                            """
                            Expose services in password auto-fill
                            from other apps.
                            """
                        } )
                        .addBehaviour( PremiumTapBehaviour() )
                        .addBehaviour( PremiumConditionalBehaviour( mode: .enables ) ),
                ToggleItem(
                        identifier: "user >biometricLock",
                        title: "Biometric Lock 🅿︎",
                        value: {
                            (icon: MPKeychainKeyFactory.factor.icon ?? MPKeychainKeyFactory.Factor.biometricTouch.icon,
                             selected: $0.biometricLock,
                             enabled: MPKeychainKeyFactory.factor != .biometricNone)
                        },
                        update: { $0.biometricLock = $1 },
                        caption: { _ in
                            """
                            Sign in using biometrics (eg. TouchID, FaceID).
                            Saves your master key in the device's key chain.
                            """
                        } )
                        .addBehaviour( PremiumTapBehaviour() )
                        .addBehaviour( PremiumConditionalBehaviour( mode: .enables ) ),
            ] )
        }
    }

    class ActionsItem: Item<MPUser> {
        init() {
            super.init( subitems: [
                ButtonItem( identifier: "user #export", value: { _ in (label: "Export", image: nil) }, action: { item in
                    if let user = item.model {
                        let controller = MPExportViewController( user: user )
                        controller.popoverPresentationController?.sourceView = item.view
                        controller.popoverPresentationController?.sourceRect = item.view.bounds
                        item.viewController?.present( controller, animated: true )
                    }
                } ),
                ButtonItem( identifier: "user #app_settings", value: { _ in (label: "Settings", image: nil) }, action: { item in
                    item.viewController?.show( MPAppDetailsViewController(), sender: item )
                } ),
                ButtonItem( identifier: "user #logout", value: { _ in (label: "Log out", image: nil) }, action: { item in
                    item.model?.logout()
                } ),
            ] )
        }
    }

    class InfoItem: Item<MPUser> {
        init() {
            super.init( title: nil, subitems: [
                UsesItem(),
                UsedItem(),
                AlgorithmItem(),
            ] )
        }
    }

    class UsesItem: LabelItem<MPUser> {
        init() {
            super.init( title: "Services", value: { $0.services.count } )
        }
    }

    class UsedItem: DateItem<MPUser> {
        init() {
            super.init( title: "Last Used", value: { $0.lastUsed } )
        }
    }

    class AlgorithmItem: LabelItem<MPUser> {
        init() {
            super.init( title: "Algorithm", value: { $0.algorithm } )
        }
    }
}
