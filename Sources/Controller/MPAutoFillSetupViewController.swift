//
// Created by Maarten Billemont on 2018-10-15.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation
import UIKit

class MPAutoFillSetupViewController: MPItemsViewController<MPUser>, /*MPUserViewController*/MPUserObserver {

    // MARK: --- Life ---

    override func loadItems() -> [Item<MPUser>] {
        [ ImageItem(
                title: "AutoFill Passwords", value: { _ in .icon( "" ) },
                caption: { _ in
                    """
                    Getting started with AutoFill on your \(UIDevice.current.name).
                    """
                } ),
            SeparatorItem(),
            Item(
                    title: "Standard Login",
                    caption: { _ in
                        """
                        To fill a password, \(productName) needs to know the login name for your services.\n
                        The standard login name is used for any service you haven't assigned a specific login name for.\n
                        (Usually, this is your e-mail address.)
                        """
                    }

            ),
            LoginTypeItem(), LoginResultItem(), SeparatorItem(),
        ]
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override init(model: MPUser, focus: Item<MPUser>.Type? = nil) {
        super.init( model: model, focus: focus )

        self.model.observers.register( observer: self ).userDidChange( self.model )
    }

    // MARK: --- MPUserObserver ---

    func userDidChange(_ user: MPUser) {
        self.setNeedsUpdate()
    }

    // MARK: --- Types ---

    class LoginTypeItem: PickerItem<MPUser, MPResultType> {
        init() {
            super.init( identifier: "user >loginType",
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
            with( MPResultTypeCell.dequeue( from: collectionView, indexPath: indexPath ) ) {
                $0.resultType = value
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
}
