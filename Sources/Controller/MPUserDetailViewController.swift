//
// Created by Maarten Billemont on 2018-10-15.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation
import UIKit

class MPUserDetailsViewController: MPDetailsViewController<MPUser>, /*MPUserViewController*/MPUserObserver {

    // MARK: --- Life ---

    override func loadItems() -> [Item<MPUser>] {
        [ IdenticonItem(), AvatarItem(), ActionsItem(), SeparatorItem(),
          PasswordTypeItem(), SeparatorItem(),
          FeaturesItem(), SeparatorItem(),
          InfoItem() ]
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override init(model: MPUser) {
        super.init( model: model )

        self.model.observers.register( observer: self ).userDidChange( self.model )
    }

    // MARK: --- MPUserObserver ---

    func userDidLogout(_ user: MPUser) {
        DispatchQueue.main.perform {
            if user == self.model, let navigationController = self.navigationController {
                trc( "Dismissing since user logged out." )
                navigationController.setViewControllers( navigationController.viewControllers.filter { $0 !== self }, animated: true )
            }
        }
    }

    func userDidChange(_ user: MPUser) {
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
            super.init( title: "Avatar",
                        values: { _ in MPUser.Avatar.allCases },
                        value: { $0.avatar },
                        update: { $0.avatar = $1 } )
        }

        override func didLoad(collectionView: UICollectionView) {
            collectionView.registerCell( MPAvatarCell.self )
        }

        override func cell(collectionView: UICollectionView, indexPath: IndexPath, model: MPUser, value: MPUser.Avatar) -> UICollectionViewCell? {
            MPAvatarCell.dequeue( from: collectionView, indexPath: indexPath ) {
                ($0 as? MPAvatarCell)?.avatar = value
            }
        }
    }

    class PasswordTypeItem: PickerItem<MPUser, MPResultType> {
        init() {
            super.init( title: "Default Type",
                        values: { _ in resultTypes.filter { !$0.has( feature: .alternative ) } },
                        value: { $0.defaultType },
                        update: { $0.defaultType = $1 } )
        }

        override func didLoad(collectionView: UICollectionView) {
            collectionView.registerCell( MPResultTypeCell.self )
        }

        override func cell(collectionView: UICollectionView, indexPath: IndexPath, model: MPUser, value: MPResultType) -> UICollectionViewCell? {
            MPResultTypeCell.dequeue( from: collectionView, indexPath: indexPath ) {
                ($0 as! MPResultTypeCell).resultType = value
            }
        }
    }

    class FeaturesItem: Item<MPUser> {
        init() {
            super.init( subitems: [
                ToggleItem<MPUser>( title: "Mask Passwords", value: { model in
                    (model.maskPasswords, UIImage( named: "icon_tripledot" ))
                }, caption: { _ in
                    """
                    Do not reveal passwords on screen.
                    Useful to deter screen snooping.
                    """
                } ) { model, maskPasswords in
                    model.maskPasswords = maskPasswords
                },
                ToggleItem( title: "Biometric Lock", value: { model in
                    (model.biometricLock, UIImage( named: "icon_man" ))
                }, caption: { _ in
                    """
                    Sign in using biometrics (eg. TouchID, FaceID).
                    Saves your master key in the device's key chain.
                    """
                } ) { model, biometricLock in
                    model.biometricLock = biometricLock
                }
            ] )
        }
    }

    class ActionsItem: Item<MPUser> {
        init() {
            super.init( subitems: [
                ButtonItem( value: { _ in (label: "Export", image: nil) } ) { item in
                    trc( "Exporting: \(item.model?.description ?? "-")" )

                    if let user = item.model {
                        let controller = MPExportViewController( user: user )
                        controller.popoverPresentationController?.sourceView = item.view
                        controller.popoverPresentationController?.sourceRect = item.view.bounds
                        item.viewController?.present( controller, animated: true )
                    }
                },
                ButtonItem( value: { _ in (label: "Log out", image: nil) } ) { item in
                    trc( "Logging out: \(item.model?.description ?? "-")" )

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
