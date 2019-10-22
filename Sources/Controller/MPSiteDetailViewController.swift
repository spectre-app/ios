//
// Created by Maarten Billemont on 2018-10-15.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation
import UIKit

class MPSiteDetailsViewController: MPDetailsViewController<MPSite>, MPSiteObserver, /*MPUserViewController*/MPUserObserver {

    // MARK: --- Life ---

    override func loadItems() -> [Item<MPSite>] {
        [ PasswordCounterItem(), SeparatorItem(),
          PasswordTypeItem(), PasswordResultItem(), SeparatorItem(),
          LoginTypeItem(), LoginResultItem(), SeparatorItem(),
          SecurityAnswerItem(), SeparatorItem(),
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
        self.imageView.image = self.model.image
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
        DispatchQueue.main.perform {
            if user == self.model.user, let navigationController = self.navigationController {
                navigationController.setViewControllers( navigationController.viewControllers.filter { $0 !== self }, animated: true )
            }
        }
    }

    // MARK: --- Types ---

    class ResultItem: LabelItem<MPSite> {
        init() {
            super.init( title: "Password & Login", value: {
                try? $0.mpw_result( keyPurpose: .authentication ).await()
            }, caption: {
                try? $0.mpw_result( keyPurpose: .identification ).await()
            } )
        }

        override func createItemView() -> ResultItemView {
            ResultItemView( withItem: self )
        }

        class ResultItemView: LabelItemView<MPSite> {
            override func didLoad(valueView: UIView) {
                super.didLoad( valueView: valueView )

                self.titleLabel.font = MPTheme.global.font.password.get()
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
            super.init( title: "Password Type", values: resultTypes.filter { !$0.has( feature: .alternative ) },
                        itemValue: { $0.resultType },
                        itemUpdate: { $0.resultType = $1 },
                        itemCell: { collectionView, indexPath, type in
                            MPResultTypeCell.dequeue( from: collectionView, indexPath: indexPath ) {
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
                        itemValue: { try? $0.mpw_result().await() },
                        itemUpdate: { site, password in
                            site.mpw_state( resultParam: password )
                                .then { state in site.resultState = state }
                        } )
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
            super.init( title: "User Name Type", values: resultTypes.filter { !$0.has( feature: .alternative ) },
                        itemValue: { $0.loginType },
                        itemUpdate: { $0.loginType = $1 },
                        itemCell: { collectionView, indexPath, type in
                            MPResultTypeCell.dequeue( from: collectionView, indexPath: indexPath ) {
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
                        itemValue: { try? $0.mpw_result( keyPurpose: .identification ).await() },
                        itemUpdate: { site, login in
                            site.mpw_state( keyPurpose: .identification, resultParam: login )
                                .then { state in site.loginState = state }
                        } )
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

    class SecurityAnswerItem: ListItem<MPSite, MPQuestion> {
        init() {
            super.init( title: "Security Answers", values: {
                var questions = [ MPQuestion( site: $0, keyword: "" ) ]
                questions.append( contentsOf: $0.questions )
                return questions
            }, subitems: [ ButtonItem( itemValue: { _ in (label: "Add Security Question", image: nil) } ) { item in
            } ], cell: { tableView, indexPath, value in
                Cell.dequeue( from: tableView, indexPath: indexPath ) {
                    ($0 as? Cell)?.question = value
                }
            } ) { tableView in
                tableView.registerCell( Cell.self )
            }
        }

        class Cell: UITableViewCell {
            private let keywordLabel = UILabel()
            private let resultLabel  = UILabel()
            private let copyButton   = MPButton( title: "copy" )

            var question: MPQuestion? {
                didSet {
                    self.keywordLabel.text = self.question?.keyword
                    self.resultLabel.text = try? self.question?.mpw_result().await()
                }
            }

            required init?(coder aDecoder: NSCoder) {
                fatalError( "init(coder:) is not supported for this class" )
            }

            override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
                super.init( style: style, reuseIdentifier: reuseIdentifier )

                // - View
                self.isOpaque = false
                self.backgroundColor = .clear

                self.keywordLabel.textColor = MPTheme.global.color.body.get()
                self.keywordLabel.shadowColor = MPTheme.global.color.shadow.get()
                self.keywordLabel.shadowOffset = CGSize( width: 0, height: 1 )
                self.keywordLabel.font = MPTheme.global.font.caption1.get()

                self.resultLabel.textColor = MPTheme.global.color.body.get()
                self.resultLabel.shadowColor = MPTheme.global.color.shadow.get()
                self.resultLabel.shadowOffset = CGSize( width: 0, height: 1 )
                self.resultLabel.font = MPTheme.global.font.password.get()
                self.resultLabel.adjustsFontSizeToFitWidth = true

                self.copyButton.button.addAction( for: .touchUpInside ) { _, _ in }
                self.copyButton.button.setContentCompressionResistancePriority( .defaultHigh + 1, for: .horizontal )

                // - Hierarchy
                self.contentView.addSubview( self.keywordLabel )
                self.contentView.addSubview( self.resultLabel )
                self.contentView.addSubview( self.copyButton )

                // - Layout
                LayoutConfiguration( view: self.keywordLabel )
                        .constrainToMarginsOfOwner( withAnchors: .topBox )
                        .activate()
                LayoutConfiguration( view: self.resultLabel )
                        .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor, constant: 8 ) }
                        .constrainTo { $1.topAnchor.constraint( equalTo: self.keywordLabel.bottomAnchor ) }
                        .constrainTo { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.bottomAnchor ) }
                        .activate()
                LayoutConfiguration( view: self.copyButton )
                        .constrainTo { $1.leadingAnchor.constraint( equalTo: self.resultLabel.trailingAnchor, constant: 8 ) }
                        .constrainTo { $1.centerYAnchor.constraint( equalTo: self.resultLabel.centerYAnchor ) }
                        .constrainTo { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.bottomAnchor ) }
                        .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor, constant: -8 ) }
                        .activate()
            }
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
            super.init( title: "Total Uses", value: { $0.uses } )
        }
    }

    class UsedItem: DateItem<MPSite> {
        init() {
            super.init( title: "Last Used", value: { $0.lastUsed } )
        }
    }

    class AlgorithmItem: LabelItem<MPSite> {
        init() {
            super.init( title: "Algorithm", value: { $0.algorithm } )
        }
    }
}
