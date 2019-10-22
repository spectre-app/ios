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
            super.init( title: "Avatar", values: MPUser.Avatar.allCases,
                        itemValue: { $0.avatar },
                        itemUpdate: { $0.avatar = $1 },
                        itemCell: { collectionView, indexPath, avatar in
                            MPAvatarCell.dequeue( from: collectionView, indexPath: indexPath ) {
                                ($0 as? MPAvatarCell)?.avatar = avatar
                            }
                        } ) { collectionView in
                collectionView.registerCell( MPAvatarCell.self )
            }
        }
    }

    class PasswordTypeItem: PickerItem<MPUser, MPResultType> {
        init() {
            super.init( title: "Default Type", values: resultTypes.filter { !$0.has( feature: .alternative ) },
                        itemValue: { $0.defaultType },
                        itemUpdate: { $0.defaultType = $1 },
                        itemCell: { collectionView, indexPath, type in
                            MPResultTypeCell.dequeue( from: collectionView, indexPath: indexPath ) {
                                ($0 as! MPResultTypeCell).resultType = type
                            }
                        } ) { collectionView in
                collectionView.registerCell( MPResultTypeCell.self )
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
                ButtonItem( itemValue: { _ in (label: "Export", image: nil) } ) { item in
                    if let user = item.model {
                        let controller = MPExportViewController( user: user )
                        controller.popoverPresentationController?.sourceView = item.view
                        controller.popoverPresentationController?.sourceRect = item.view.bounds
                        item.viewController?.present( controller, animated: true )
                    }
                },
                ButtonItem( itemValue: { _ in (label: "Log out", image: nil) } ) { item in
                    item.model?.masterKeyFactory = nil
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
