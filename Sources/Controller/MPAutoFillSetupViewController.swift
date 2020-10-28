//
// Created by Maarten Billemont on 2018-10-15.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation
import UIKit

class MPAutoFillSetupViewController: MPItemsViewController<MPUser>, /*MPUserViewController*/MPUserObserver {

    // MARK: --- Life ---

    override func loadItems() -> [Item<MPUser>] {
        [ ImageItem( title: "AutoFill Passwords", value: { _ in .icon( "", withSize: 64 ) },
                     caption: { _ in
                         """
                         Getting started with AutoFill on your \(UIDevice.current.model).
                         """
                     } ),
            SeparatorItem(),
            PagerItem( value: { _ in
                [
                    Item( subitems: [
                        Item(
                                title: "Step 1\nSet a standard login name",
                                caption: { _ in
                                    """
                                    To autofill, \(productName) will need your service's login name.
                                    No need to set one for every service individually!\n
                                    Use your most usual login name as your standard login.
                                    Select "\(MPResultType.statefulPersonal.abbreviation)" to save an e‑mail address or nickname. 
                                    """
                                }
                        ),
                        LoginTypeItem(), LoginResultItem(),
                    ], axis: .vertical ),
                    Item( subitems: [
                        Item(
                                title: "Step 2\nSet a standard login name",
                                caption: { _ in
                                    """
                                    To autofill, \(productName) will need your service's login name.
                                    No need to set one for every service individually!\n
                                    Use your most usual login name as your standard login.
                                    Select "\(MPResultType.statefulPersonal.abbreviation)" to save an e‑mail address or nickname. 
                                    """
                                }
                        ),
                        LoginTypeItem(), LoginResultItem(),
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
    }

    // MARK: --- MPUserObserver ---

    func userDidChange(_ user: MPUser) {
        self.setNeedsUpdate()
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
}
