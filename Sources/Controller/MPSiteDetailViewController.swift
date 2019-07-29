//
// Created by Maarten Billemont on 2018-10-15.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation
import UIKit

class MPSiteDetailsViewController: MPDetailsViewController<MPSite>, MPSiteObserver, /*MPUserViewController*/MPUserObserver {

    // MARK: --- Life ---

    override func loadItems() -> [Item<MPSite>] {
        return [ PasswordCounterItem(), SeparatorItem(),
                 PasswordTypeItem(), PasswordResultItem(), SeparatorItem(),
                 LoginTypeItem(), LoginResultItem(), SeparatorItem(),
                 URLItem(), SeparatorItem(),
                 InfoItem() ]
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override init(model: MPSite) {
        super.init( model: model )

        self.model.observers.register( observer: self ).siteDidChange( self.model )
        self.model.user.observers.register( observer: self )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.tintColor = self.model.color
    }

    // MARK: --- MPSiteObserver ---

    func siteDidChange(_ site: MPSite) {
        DispatchQueue.main.perform {
            self.viewIfLoaded?.tintColor = self.model.color
        }

        self.setNeedsUpdate()
    }

    // MARK: --- MPUserObserver ---

    func userDidLogout(_ user: MPUser) {
        if user == self.model, let navigationController = self.navigationController {
            navigationController.setViewControllers( navigationController.viewControllers.filter { $0 !== self }, animated: true )
        }
    }

    // MARK: --- Types ---

    class ResultItem: LabelItem<MPSite> {
        init() {
            super.init( title: "Password & Login" ) {
                ($0.mpw_result() ?? "", $0.mpw_login() ?? "")
            }
        }

        override func createItemView() -> ResultItemView {
            return ResultItemView( withItem: self )
        }

        class ResultItemView: LabelItemView<MPSite> {
            override func didLoad(valueView: UIView) {
                super.didLoad( valueView: valueView )

                self.primaryLabel.font = MPTheme.global.font.password.get()
            }
        }
    }

    class PasswordCounterItem: StepperItem<MPSite, UInt32> {
        init() {
            super.init( title: "Password Counter",
                        itemValue: { $0.counter.rawValue },
                        itemUpdate: { $0.counter = MPCounterValue( rawValue: $1 ) ?? .default },
                        step: 1, min: MPCounterValue.initial.rawValue, max: MPCounterValue.last.rawValue )
        }
    }

    class PasswordTypeItem: PickerItem<MPSite, MPResultType> {
        init() {
            super.init( title: "Password Type", values: [ MPResultType ]( MPResultTypes ).filter { !$0.has( feature: .alternative ) },
                        itemValue: { $0.resultType },
                        itemUpdate: { $0.resultType = $1 },
                        itemCell: { collectionView, indexPath, type in
                            return MPResultTypeCell.dequeue( from: collectionView, indexPath: indexPath ) {
                                ($0 as? MPResultTypeCell)?.resultType = type
                            }
                        } ) { collectionView in
                collectionView.registerCell( MPResultTypeCell.self )
            }
        }
    }

    class PasswordResultItem: TextItem<MPSite> {
        init() {
            super.init( title: nil, placeholder: "set a password",
                        itemValue: { $0.mpw_result() },
                        itemUpdate: { $0.mpw_result_save( resultParam: $1 ) } )
        }

        override func createItemView() -> TextItemView<MPSite> {
            let view = super.createItemView()
            view.valueField.font = MPTheme.global.font.password.get()
            view.valueField.autocapitalizationType = .none
            view.valueField.autocorrectionType = .no
            return view
        }

        override func doUpdate() {
            super.doUpdate()

            (self.view as? TextItemView<MPSite>)?.valueField.isEnabled = self.model?.resultType.in( class: .stateful ) ?? false
        }
    }

    class LoginTypeItem: PickerItem<MPSite, MPResultType> {
        init() {
            super.init( title: "User Name Type", values: [ MPResultType ]( MPResultTypes ).filter { !$0.has( feature: .alternative ) },
                        itemValue: { $0.loginType },
                        itemUpdate: { $0.loginType = $1 },
                        itemCell: { collectionView, indexPath, type in
                            return MPResultTypeCell.dequeue( from: collectionView, indexPath: indexPath ) {
                                ($0 as? MPResultTypeCell)?.resultType = type
                            }
                        } ) { collectionView in
                collectionView.registerCell( MPResultTypeCell.self )
            }
        }
    }

    class LoginResultItem: TextItem<MPSite> {
        init() {
            super.init( title: nil, placeholder: "set a user name",
                        itemValue: { $0.mpw_login() },
                        itemUpdate: { $0.mpw_login_save( resultParam: $1 ) } )
        }

        override func createItemView() -> TextItemView<MPSite> {
            let view = super.createItemView()
            view.valueField.font = MPTheme.global.font.mono.get()
            view.valueField.autocapitalizationType = .none
            view.valueField.autocorrectionType = .no
            return view
        }

        override func doUpdate() {
            super.doUpdate()

            (self.view as? TextItemView<MPSite>)?.valueField.isEnabled = self.model?.resultType.in( class: .stateful ) ?? false
        }
    }

    class URLItem: TextItem<MPSite> {
        init() {
            super.init( title: "URL", placeholder: "eg. https://www.apple.com",
                        itemValue: { $0.url },
                        itemUpdate: { $0.url = $1 } )
        }

        override func createItemView() -> TextItemView<MPSite> {
            let itemView = super.createItemView()
            itemView.valueField.autocapitalizationType = .none
            itemView.valueField.autocorrectionType = .no
            itemView.valueField.keyboardType = .URL
            return itemView
        }
    }

    class InfoItem: Item<MPSite> {
        init() {
            super.init( title: nil, subitems: [
                UsesItem(),
                UsedItem(),
                AlgorithmItem(),
            ] )
        }
    }

    class UsesItem: LabelItem<MPSite> {
        init() {
            super.init( title: "Total Uses" ) { ("\($0.uses)", nil) }
        }
    }

    class UsedItem: DateItem<MPSite> {
        init() {
            super.init( title: "Last Used" ) { $0.lastUsed }
        }
    }

    class AlgorithmItem: LabelItem<MPSite> {
        init() {
            super.init( title: "Algorithm" ) { ("v\($0.algorithm.rawValue)", nil) }
        }
    }
}
