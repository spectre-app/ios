//
// Created by Maarten Billemont on 2018-10-15.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation
import UIKit

class MPUserDetailsViewController: MPDetailsViewController<MPUser>, /*MPUserViewController*/MPUserObserver {

    // MARK: --- Life ---

    override func loadItems() -> [Item<MPUser>] {
        return [ IdenticonItem(), AvatarItem(), SeparatorItem(),
                 PasswordTypeItem(), SeparatorItem(),
                 FeaturesItem(), SeparatorItem(),
                 ActionsItem(), SeparatorItem(),
                 InfoItem() ]
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override init(model: MPUser) {
        super.init( model: model )

        self.model.observers.register( observer: self ).userDidChange( self.model )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.backgroundView.backgroundColor = MPTheme.global.color.brand.get()
        self.view.tintColor = MPTheme.global.color.brand.get()
    }

    // MARK: --- MPUserObserver ---

    func userDidLogout(_ user: MPUser) {
        if user == self.model, let navigationController = self.navigationController {
            navigationController.setViewControllers( navigationController.viewControllers.filter { $0 !== self }, animated: true )
        }
    }

    func userDidChange(_ user: MPUser) {
        self.setNeedsUpdate()
    }

    // MARK: --- Types ---

    class IdenticonItem: LabelItem<MPUser> {
        init() {
            super.init( itemValue: { ($0.identicon.attributedText(), $0.fullName) } )
        }
    }

    class AvatarItem: PickerItem<MPUser, MPUser.Avatar> {
        init() {
            super.init( title: "Avatar", values: MPUser.Avatar.allCases,
                        itemValue: { $0.avatar },
                        itemUpdate: { $0.avatar = $1 },
                        itemCell: { collectionView, indexPath, avatar in
                            return MPAvatarCell.dequeue( from: collectionView, indexPath: indexPath ) {
                                ($0 as? MPAvatarCell)?.avatar = avatar
                            }
                        } ) {
                $0.registerCell( MPAvatarCell.self )
            }
        }
    }

    class PasswordTypeItem: PickerItem<MPUser, MPResultType> {
        init() {
            super.init( title: "Default Type", values: [ MPResultType ]( MPResultTypes ).filter { !$0.has( feature: .alternative ) },
                        itemValue: { $0.defaultType },
                        itemUpdate: { $0.defaultType = $1 },
                        itemCell: { collectionView, indexPath, type in
                            return MPResultTypeCell.dequeue( from: collectionView, indexPath: indexPath ) {
                                ($0 as! MPResultTypeCell).resultType = type
                            }
                        } ) {
                $0.registerCell( MPResultTypeCell.self )
            }
        }
    }

    class FeaturesItem: Item<MPUser> {
    }

    class ActionsItem: Item<MPUser> {
        init() {
            super.init( subitems: [
                ButtonItem( itemValue: { _ in ("📤 Export", nil) } ) { item in
                    if let user = item.model {
                        let controller = MPExportViewController( user: user )
                        controller.popoverPresentationController?.sourceView = item.view
                        controller.popoverPresentationController?.sourceRect = item.view.bounds
                        item.viewController?.present( controller, animated: true )
                    }
                },
                ButtonItem( itemValue: { _ in ("⎋ Log out", nil) } ) { item in
                    item.model?.masterKey = nil
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
            super.init( title: "Sites" ) { ("\($0.sites.count)", nil) }
        }
    }

    class UsedItem: DateItem<MPUser> {
        init() {
            super.init( title: "Last Used" ) { $0.lastUsed }
        }
    }

    class AlgorithmItem: LabelItem<MPUser> {
        init() {
            super.init( title: "Algorithm" ) { ("v\($0.algorithm.rawValue)", nil) }
        }
    }
}
