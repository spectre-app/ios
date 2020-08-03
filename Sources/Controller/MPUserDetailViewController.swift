//
// Created by Maarten Billemont on 2018-10-15.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation
import UIKit

class MPUserDetailsViewController: MPDetailsViewController<MPUser>, /*MPUserViewController*/MPUserObserver, MPConfigObserver {

    // MARK: --- Life ---

    override func loadItems() -> [Item<MPUser>] {
        [ IdenticonItem(), AvatarItem(), ActionsItem(), SeparatorItem(),
          DefaultTypeItem(), SeparatorItem(),
          AttackerItem(), SeparatorItem(),
          FeaturesItem(), SeparatorItem(),
          InfoItem() ]
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override init(model: MPUser) {
        super.init( model: model )

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

    class DefaultTypeItem: PickerItem<MPUser, MPResultType> {
        init() {
            super.init( identifier: "user >defaultType", title: "Default Type",
                        values: { _ in resultTypes.filter { !$0.has( feature: .alternative ) } },
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
            super.init( identifier: "user >attacker", title: "Defense Strategy 🅿",
                        values: { _ in MPAttacker.allCases },
                        value: { $0.attacker },
                        update: { $0.attacker = $1 },
                        caption: { _ in
                            """
                            Yearly budget of the primary attacker persona you're seeking to repel (@ \(cost_per_kwh)$/kWh).
                            """
                        } )
            self.addBehaviour( RequiresPremium() )
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
                            self.nameLabel.text = "\(amount: attacker.fixed_budget + attacker.monthly_budget * 12)$"
                            self.classLabel.text = "\(attacker)"
                        }
                        else {
                            self.nameLabel.text = "Off"
                            self.classLabel.text = ""
                        }
                    }
                }
            }
        }
    }

    class FeaturesItem: Item<MPUser> {
        init() {
            super.init( subitems: [
                ToggleItem<MPUser>(
                        identifier: "user >maskPasswords",
                        title: "Mask Passwords",
                        value: {
                            (icon: UIImage.icon( "" ),
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
                ToggleItem(
                        identifier: "user >biometricLock",
                        title: "Biometric Lock 🅿",
                        value: {
                            let keychainKeyFactory = MPKeychainKeyFactory( fullName: $0.fullName )
                            return (icon: keychainKeyFactory.factor.icon ?? MPKeychainKeyFactory.Factor.biometricTouch.icon,
                                    selected: $0.biometricLock,
                                    enabled: keychainKeyFactory.factor != .biometricNone)
                        },
                        update: { $0.biometricLock = $1 },
                        caption: { _ in
                            """
                            Sign in using biometrics (eg. TouchID, FaceID).
                            Saves your master key in the device's key chain.
                            """
                        } )
                        .addBehaviour( RequiresPremium() ) ] )
        }
    }

    class ActionsItem: Item<MPUser> {
        init() {
            super.init( subitems: [
                ButtonItem( identifier: "user #export", value: { _ in (label: "Export", image: nil) } ) { item in
                    trc( "Exporting: %@", item.model )

                    if let user = item.model {
                        let controller = MPExportViewController( user: user )
                        controller.popoverPresentationController?.sourceView = item.view
                        controller.popoverPresentationController?.sourceRect = item.view.bounds
                        item.viewController?.present( controller, animated: true )
                    }
                },
                ButtonItem( identifier: "user #logout", value: { _ in (label: "Log out", image: nil) } ) { item in
                    trc( "Logging out: %@", item.model )

                    item.model?.logout()
                },
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
            super.init( title: "Sites", value: { $0.sites.count } )
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
