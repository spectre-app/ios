//
// Created by Maarten Billemont on 2018-10-15.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation
import UIKit

class MPSiteDetailsViewController: MPDetailsViewController<MPSite>, MPSiteObserver, MPConfigObserver {

    // MARK: --- Life ---

    override func loadItems() -> [Item<MPSite>] {
        [ PasswordCounterItem(), SeparatorItem(),
          PasswordTypeItem(), PasswordResultItem(), SeparatorItem(),
          LoginTypeItem(), LoginResultItem(), SeparatorItem( hidden: { _ in !appConfig.premium } ),
          SecurityAnswerItem(), SeparatorItem( hidden: { _ in !appConfig.premium } ),
          URLItem(), SeparatorItem(),
          InfoItem() ]
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override init(model: MPSite) {
        super.init( model: model )

        self.model.observers.register( observer: self ).siteDidChange( self.model )
        appConfig.observers.register( observer: self )
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

    // MARK: --- MPSiteObserver ---

    func didChangeConfig() {
        self.setNeedsUpdate()
    }

    // MARK: --- Types ---

    class PasswordCounterItem: StepperItem<MPSite, UInt32> {
        init() {
            super.init( title: "Password Counter",
                        value: { $0.counter.rawValue },
                        update: { $0.counter = MPCounterValue( rawValue: $1 ) ?? .default },
                        step: 1, min: MPCounterValue.initial.rawValue, max: MPCounterValue.last.rawValue )
        }
    }

    class PasswordTypeItem: PickerItem<MPSite, MPResultType> {
        init() {
            super.init( title: "Password Type",
                        values: { _ in resultTypes.filter { !$0.has( feature: .alternative ) } },
                        value: { $0.resultType },
                        update: { $0.resultType = $1 } )
        }

        override func didLoad(collectionView: UICollectionView) {
            collectionView.registerCell( MPResultTypeCell.self )
        }

        override func cell(collectionView: UICollectionView, indexPath: IndexPath, model: MPSite, value: MPResultType) -> UICollectionViewCell? {
            MPResultTypeCell.dequeue( from: collectionView, indexPath: indexPath ) {
                ($0 as? MPResultTypeCell)?.resultType = value
            }
        }
    }

    class PasswordResultItem: FieldItem<MPSite> {
        init() {
            super.init( title: nil, placeholder: "set a password",
                        value: { try? $0.mpw_result().await() },
                        update: { site, password in
                            site.mpw_state( resultParam: password ).then {
                                switch $0 {
                                    case .success(let state):
                                        site.resultState = state

                                    case .failure(let error):
                                        mperror( title: "Couldn't update site password", error: error )
                                }
                            }
                        },
                        caption: {
                            guard appConfig.premium, let attacker = $0.user.attacker,
                                  let timeToCrack = attacker.timeToCrack( type: $0.resultType )
                            else { return nil }

                            return "Time to crack: \(timeToCrack) 🅿"
                        } )
        }

        override func createItemView() -> FieldItemView<MPSite> {
            let view = super.createItemView()
            view.valueField.font = appConfig.theme.font.password.get()
            view.valueField.autocapitalizationType = .none
            view.valueField.autocorrectionType = .no
            view.valueField.keyboardType = .asciiCapable
            return view
        }

        override func doUpdate() {
            super.doUpdate()

            (self.view as? FieldItemView<MPSite>)?.valueField.isEnabled = self.model?.resultType.in( class: .stateful ) ?? false
        }
    }

    class LoginTypeItem: PickerItem<MPSite, MPResultType> {
        init() {
            super.init( title: "User Name Type 🅿",
                        values: { _ in resultTypes.filter { !$0.has( feature: .alternative ) } },
                        value: { $0.loginType },
                        update: { $0.loginType = $1 },
                        hidden: { _ in !appConfig.premium } )
        }

        override func didLoad(collectionView: UICollectionView) {
            collectionView.registerCell( MPResultTypeCell.self )
        }

        override func cell(collectionView: UICollectionView, indexPath: IndexPath, model: MPSite, value: MPResultType) -> UICollectionViewCell? {
            MPResultTypeCell.dequeue( from: collectionView, indexPath: indexPath ) {
                ($0 as? MPResultTypeCell)?.resultType = value
            }
        }
    }

    class LoginResultItem: FieldItem<MPSite> {
        init() {
            super.init( title: nil, placeholder: "set a user name",
                        value: { try? $0.mpw_result( keyPurpose: .identification ).await() },
                        update: { site, login in
                            site.mpw_state( keyPurpose: .identification, resultParam: login ).then {
                                switch $0 {
                                    case .success(let state):
                                        site.loginState = state

                                    case .failure(let error):
                                        mperror( title: "Couldn't update site name", error: error )
                                }
                            }
                        },
                        hidden: { _ in !appConfig.premium } )
        }

        override func createItemView() -> FieldItemView<MPSite> {
            let view = super.createItemView()
            view.valueField.font = appConfig.theme.font.password.get()
            view.valueField.autocapitalizationType = .none
            view.valueField.autocorrectionType = .no
            view.valueField.keyboardType = .emailAddress
            return view
        }

        override func doUpdate() {
            super.doUpdate()

            (self.view as? FieldItemView<MPSite>)?.valueField.isEnabled = self.model?.resultType.in( class: .stateful ) ?? false
        }
    }

    class SecurityAnswerItem: ListItem<MPSite, MPQuestion> {
        init() {
            super.init(
                    title: "Security Answers 🅿",
                    values: {
                        $0.questions.reduce( [ "": MPQuestion( site: $0, keyword: "" ) ] ) {
                            $0.merging( [ $1.keyword: $1 ], uniquingKeysWith: { $1 } )
                        }.values.sorted()
                    },
                    subitems: [ ButtonItem( value: { _ in (label: "Add Security Question", image: nil) } ) { item in
                        let controller = UIAlertController( title: "Security Question", message:
                        """
                        Enter the most significant noun for the site's security question.
                        """, preferredStyle: .alert )
                        controller.addTextField {
                            $0.placeholder = "eg. teacher"
                            $0.autocapitalizationType = .none
                            $0.keyboardType = .alphabet
                            $0.returnKeyType = .done
                        }
                        controller.addAction( UIAlertAction( title: "Cancel", style: .cancel ) )
                        controller.addAction( UIAlertAction( title: "Add", style: .default ) { [weak item, weak controller] _ in
                            guard let site = item?.model, let keyword = controller?.textFields?.first?.text<
                            else { return }

                            trc( "Adding security question <\(keyword)> for: \(site)" )
                            site.questions.append( MPQuestion( site: site, keyword: keyword ) )
                        } )
                        item.viewController?.present( controller, animated: true )
                    } ],
                    hidden: { _ in !appConfig.premium } )

            self.deletable = true
        }

        override func didLoad(tableView: UITableView) {
            tableView.registerCell( Cell.self )
        }

        override func cell(tableView: UITableView, indexPath: IndexPath, model: MPSite, value: MPQuestion) -> UITableViewCell? {
            Cell.dequeue( from: tableView, indexPath: indexPath ) {
                ($0 as? Cell)?.question = value
            }
        }

        override func delete(model: MPSite, value: MPQuestion) {
            trc( "Trashing security question: \(value)" )

            model.questions.removeAll { $0 === value }
        }

        class Cell: UITableViewCell {
            private let keywordLabel = UILabel()
            private let resultLabel  = UILabel()
            private let copyButton   = MPButton( title: "copy" )

            weak var question: MPQuestion? {
                didSet {
                    self.question?.mpw_result().then( on: .main ) {
                        switch $0 {
                            case .success(let answer):
                                self.resultLabel.text = answer
                                self.keywordLabel.text = self.question?.keyword< ?? "(generic)"

                            case .failure(let error):
                                mperror( title: "Couldn't calculate security answer", error: error )
                        }
                    }
                }
            }

            // MARK: --- Life ---

            required init?(coder aDecoder: NSCoder) {
                fatalError( "init(coder:) is not supported for this class" )
            }

            override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
                super.init( style: style, reuseIdentifier: reuseIdentifier )

                // - View
                self.isOpaque = false
                self.backgroundColor = .clear

                self.keywordLabel.font = appConfig.theme.font.caption1.get()
                self.keywordLabel.shadowColor = appConfig.theme.color.shadow.get()
                self.keywordLabel.shadowOffset = CGSize( width: 0, height: 1 )
                self.keywordLabel.textColor = appConfig.theme.color.body.get()

                self.resultLabel.font = appConfig.theme.font.password.get()
                self.resultLabel.shadowColor = appConfig.theme.color.shadow.get()
                self.resultLabel.shadowOffset = CGSize( width: 0, height: 1 )
                self.resultLabel.textColor = appConfig.theme.color.body.get()
                self.resultLabel.adjustsFontSizeToFitWidth = true

                self.copyButton.button.addAction( for: .touchUpInside ) { [unowned self] _, _ in
                    self.question?.mpw_copy()
                }

                // - Hierarchy
                self.contentView.addSubview( self.keywordLabel )
                self.contentView.addSubview( self.resultLabel )
                self.contentView.addSubview( self.copyButton )

                // - Layout
                LayoutConfiguration( view: self.resultLabel )
                        .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                        .constrainTo { $1.topAnchor.constraint( lessThanOrEqualTo: $0.layoutMarginsGuide.topAnchor ) }
                        .activate()
                LayoutConfiguration( view: self.keywordLabel )
                        .constrainTo { $1.topAnchor.constraint( equalTo: self.resultLabel.bottomAnchor ) }
                        .constrainTo { $1.leadingAnchor.constraint( equalTo: self.resultLabel.leadingAnchor ) }
                        .constrainTo { $1.trailingAnchor.constraint( equalTo: self.resultLabel.trailingAnchor ) }
                        .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.layoutMarginsGuide.bottomAnchor ) }
                        .activate()
                LayoutConfiguration( view: self.copyButton )
                        .constrainTo { $1.topAnchor.constraint( greaterThanOrEqualTo: $0.layoutMarginsGuide.topAnchor ) }
                        .constrainTo { $1.leadingAnchor.constraint( equalTo: self.resultLabel.trailingAnchor, constant: 8 ) }
                        .constrainTo { $1.centerYAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerYAnchor ) }
                        .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                        .constrainTo { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.layoutMarginsGuide.bottomAnchor ) }
                        .activate()
            }
        }
    }

    class URLItem: FieldItem<MPSite> {
        init() {
            super.init( title: "URL", placeholder: "eg. https://www.apple.com",
                        value: { $0.url },
                        update: { $0.url = $1 } )
        }

        override func createItemView() -> FieldItemView<MPSite> {
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
