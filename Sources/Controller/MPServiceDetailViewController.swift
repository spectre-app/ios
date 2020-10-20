//
// Created by Maarten Billemont on 2018-10-15.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation
import UIKit

class MPServiceDetailsViewController: MPItemsViewController<MPService>, MPServiceObserver {

    // MARK: --- Life ---

    override func loadItems() -> [Item<MPService>] {
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

    override init(model: MPService, focus: Item<MPService>.Type? = nil) {
        super.init( model: model, focus: focus )

        self.model.observers.register( observer: self ).serviceDidChange( self.model )
    }

    // MARK: --- MPServiceObserver ---

    func serviceDidChange(_ service: MPService) {
        DispatchQueue.main.perform {
            self.color = self.model.color
            self.image = self.model.image
        }

        self.setNeedsUpdate()
    }

    // MARK: --- Types ---

    class PasswordCounterItem: StepperItem<MPService, UInt32> {
        init() {
            super.init( title: "Password Counter",
                        value: { $0.counter.rawValue },
                        update: { $0.counter = MPCounterValue( rawValue: $1 ) ?? .default },
                        step: 1, min: MPCounterValue.initial.rawValue, max: MPCounterValue.last.rawValue,
                        caption: { _ in
                            """
                            Increment the counter if you need to change the service's current password.
                            """
                        } )
        }
    }

    class PasswordTypeItem: PickerItem<MPService, MPResultType> {
        init() {
            super.init( identifier: "service >resultType", title: "Password Type",
                        values: { _ in
                            [ MPResultType? ].joined(
                                    separator: [ nil ],
                                    MPResultType.recommendedTypes[.authentication],
                                    [ MPResultType.statefulPersonal ],
                                    MPResultType.allCases.filter { !$0.has( feature: .alternative ) } ).unique()
                        },
                        value: { $0.resultType },
                        update: { $0.resultType = $1 } )
        }

        override func didLoad(collectionView: UICollectionView) {
            collectionView.register( MPResultTypeCell.self )
        }

        override func cell(collectionView: UICollectionView, indexPath: IndexPath, model: MPService, value: MPResultType) -> UICollectionViewCell? {
            with(MPResultTypeCell.dequeue( from: collectionView, indexPath: indexPath )) {
                $0.resultType = value
            }
        }
    }

    class PasswordResultItem: FieldItem<MPService> {
        init() {
            super.init( title: nil, placeholder: "set a password",
                        value: { try? $0.result().token.await() },
                        update: { service, password in
                            MPTracker.shared.event( named: "service >password", [
                                "type": "\(service.resultType)",
                                "entropy": MPAttacker.entropy( string: password ) ?? 0,
                            ] )

                            service.state( resultParam: password ).token.then {
                                do { service.resultState = try $0.get() }
                                catch { mperror( title: "Couldn't update service password", error: error ) }
                            }
                        },
                        caption: {
                            let attacker = $0.user.attacker ?? .default
                            if InAppFeature.premium.enabled(),
                               let timeToCrack = attacker.timeToCrack( type: $0.resultType ) ??
                                       attacker.timeToCrack( string: try? $0.result().token.await() ) {
                                return "Time to crack: \(timeToCrack) 🅿︎"
                            }
                            else {
                                return "Time to crack: unknown 🅿︎"
                            }
                        } )
        }

        override func createItemView() -> FieldItemView<MPService> {
            let view = super.createItemView()
            view.valueField => \.font => Theme.current.font.password
            view.valueField.autocapitalizationType = .none
            view.valueField.autocorrectionType = .no
            view.valueField.keyboardType = .asciiCapable
            return view
        }

        override func update() {
            super.update()

            (self.view as? FieldItemView<MPService>)?.valueField.isEnabled = self.model?.resultType.in( class: .stateful ) ?? false
        }
    }

    class LoginTypeItem: PickerItem<MPService, MPResultType> {
        init() {
            super.init( identifier: "service >loginType", title: "User Name Type 🅿︎",
                        values: { _ in
                            [ MPResultType? ].joined(
                                    separator: [ nil ],
                                    [ MPResultType.none ],
                                    MPResultType.recommendedTypes[.identification],
                                    [ MPResultType.statefulPersonal ],
                                    MPResultType.allCases.filter { !$0.has( feature: .alternative ) } ).unique()
                        },
                        value: { $0.loginType },
                        update: { $0.loginType = $1 } )

            self.addBehaviour( PremiumTapBehaviour() )
            self.addBehaviour( PremiumConditionalBehaviour( mode: .enables ) )
        }

        override func didLoad(collectionView: UICollectionView) {
            collectionView.register( MPResultTypeCell.self )
        }

        override func cell(collectionView: UICollectionView, indexPath: IndexPath, model: MPService, value: MPResultType) -> UICollectionViewCell? {
            with( MPResultTypeCell.dequeue( from: collectionView, indexPath: indexPath ) ) {
                $0.resultType = value.nonEmpty

                if value == .none {
                    $0.name = nil
                    $0.class = "Standard Login"
                }
            }
        }
    }

    class LoginResultItem: FieldItem<MPService> {
        let userView = MPButton( identifier: "service.login #user" )

        init() {
            super.init( title: nil, placeholder: "set a user name",
                        value: { try? $0.result( keyPurpose: .identification ).token.await() },
                        update: { service, login in
                            MPTracker.shared.event( named: "service >login", [
                                "type": "\(service.loginType)",
                                "entropy": MPAttacker.entropy( string: login ) ?? 0,
                            ] )

                            service.state( keyPurpose: .identification, resultParam: login ).token.then {
                                do { service.loginState = try $0.get() }
                                catch { mperror( title: "Couldn't update service name", error: error ) }
                            }
                        },
                        caption: {
                            $0.loginType == .none ?
                                    "The service uses your Standard Login Name.":
                                    "The service is using a service‑specific login name."
                        } )

            self.addBehaviour( PremiumConditionalBehaviour( mode: .reveals ) )
        }

        override func createItemView() -> FieldItemView<MPService> {
            let view = super.createItemView()
            view.valueField => \.font => Theme.current.font.password
            view.valueField.autocapitalizationType = .none
            view.valueField.autocorrectionType = .no
            view.valueField.keyboardType = .emailAddress
            view.valueField.leftView = MPMarginView( for: self.userView, margins: .border( 4 ) )

            self.userView.isRound = true
            self.userView.action( for: .primaryActionTriggered ) { [unowned self] in
                if let user = self.model?.user, self.model?.loginType == MPResultType.none {
                    self.viewController?.show(
                            MPUserDetailsViewController( model: user, focus: MPUserDetailsViewController.LoginTypeItem.self ), sender: self )
                }
            }

            return view
        }

        override func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
            super.textFieldShouldBeginEditing( textField ) && (self.model?.loginType.in( class: .stateful ) ?? false)
        }

        override func update() {
            super.update()

            self.userView.title = self.model?.user.fullName.name( style: .abbreviated )
            self.userView.sizeToFit()

            (self.view as? FieldItemView<MPService>)?.valueField.leftViewMode = self.model?.loginType == MPResultType.none ? .always: .never
        }
    }

    class SecurityAnswerItem: ListItem<MPService, MPQuestion> {
        init() {
            super.init( title: "Security Answers 🅿︎",
                        values: {
                            $0.questions.reduce( [ "": MPQuestion( service: $0, keyword: "" ) ] ) {
                                $0.merging( [ $1.keyword: $1 ], uniquingKeysWith: { $1 } )
                            }.values.sorted()
                        },
                        subitems: [
                            ButtonItem( identifier: "service.question #add",
                                        value: { _ in (label: "Add Security Question", image: nil) },
                                        action: { item in
                                            let controller = UIAlertController( title: "Security Question", message:
                                            """
                                            Enter the most significant noun for the service's security question.
                                            """, preferredStyle: .alert )
                                            controller.addTextField {
                                                $0.placeholder = "eg. teacher"
                                                $0.autocapitalizationType = .none
                                                $0.keyboardType = .alphabet
                                                $0.returnKeyType = .done
                                            }
                                            controller.addAction( UIAlertAction( title: "Cancel", style: .cancel ) )
                                            controller.addAction( UIAlertAction( title: "Add", style: .default ) { [weak item, weak controller] _ in
                                                guard let service = item?.model, let keyword = controller?.textFields?.first?.text?.nonEmpty
                                                else { return }

                                                trc( "Adding security question <%@> for: %@", keyword, service )
                                                service.questions.append( MPQuestion( service: service, keyword: keyword ) )
                                            } )
                                            item.viewController?.present( controller, animated: true )
                                        } )
                        ],
                        caption: { _ in
                            """
                            Security questions are an invasive loophole for bypassing your password.
                            Use these cryptographically private answers instead.
                            """
                        } )
            self.deletable = true

            self.addBehaviour( PremiumTapBehaviour() )
            self.addBehaviour( PremiumConditionalBehaviour( mode: .enables ) )
        }

        override func didLoad(tableView: UITableView) {
            super.didLoad( tableView: tableView )

            tableView.register( Cell.self )
        }

        override func cell(tableView: UITableView, indexPath: IndexPath, model: MPService, value: MPQuestion) -> UITableViewCell? {
            Cell.dequeue( from: tableView, indexPath: indexPath ) {
                ($0 as? Cell)?.question = value
            }
        }

        override func delete(model: MPService, value: MPQuestion) {
            trc( "Trashing security question: %@", value )

            model.questions.removeAll { $0 === value }
        }

        class Cell: UITableViewCell {
            private let keywordLabel = UILabel()
            private let resultLabel  = UILabel()
            private let copyButton   = MPButton( identifier: "service.question #copy", title: "copy" )

            weak var question: MPQuestion? {
                didSet {
                    self.question?.result().token.then( on: .main ) {
                        do {
                            self.resultLabel.text = try $0.get()
                            self.keywordLabel.text = self.question?.keyword.nonEmpty ?? "(generic)"
                        }
                        catch {
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

                self.keywordLabel => \.font => Theme.current.font.caption1
                self.keywordLabel => \.shadowColor => Theme.current.color.shadow
                self.keywordLabel.shadowOffset = CGSize( width: 0, height: 1 )
                self.keywordLabel => \.textColor => Theme.current.color.body

                self.resultLabel => \.font => Theme.current.font.password
                self.resultLabel => \.shadowColor => Theme.current.color.shadow
                self.resultLabel.shadowOffset = CGSize( width: 0, height: 1 )
                self.resultLabel => \.textColor => Theme.current.color.body
                self.resultLabel.adjustsFontSizeToFitWidth = true

                self.copyButton.action( for: .primaryActionTriggered ) { [unowned self] in
                    let event = MPTracker.shared.begin( named: "service.question #copy" )
                    self.question?.result().copy( from: self ).then {
                        do {
                            let (operation, token) = try $0.get()
                            event.end(
                                    [ "result": $0.name,
                                      "from": "service>details",
                                      "counter": "\(operation.counter)",
                                      "purpose": "\(operation.purpose)",
                                      "type": "\(operation.type)",
                                      "algorithm": "\(operation.algorithm)",
                                      "entropy": MPAttacker.entropy( type: operation.type ) ?? MPAttacker.entropy( string: token ) ?? 0,
                                    ] )
                        }
                        catch {
                            event.end( [ "result": $0.name ] )
                        }
                    }
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

    class URLItem: FieldItem<MPService> {
        init() {
            super.init( title: "URL", placeholder: "eg. https://www.apple.com",
                        value: { $0.url },
                        update: { $0.url = $1 } )
        }

        override func createItemView() -> FieldItemView<MPService> {
            let itemView = super.createItemView()
            itemView.valueField.autocapitalizationType = .none
            itemView.valueField.autocorrectionType = .no
            itemView.valueField.keyboardType = .URL
            return itemView
        }
    }

    class InfoItem: Item<MPService> {
        init() {
            super.init( title: nil, subitems: [
                UsesItem(),
                UsedItem(),
                AlgorithmItem(),
            ] )
        }
    }

    class UsesItem: LabelItem<MPService> {
        init() {
            super.init( title: "Total Uses", value: { $0.uses } )
        }
    }

    class UsedItem: DateItem<MPService> {
        init() {
            super.init( title: "Last Used", value: { $0.lastUsed } )
        }
    }

    class AlgorithmItem: LabelItem<MPService> {
        init() {
            super.init( title: "Algorithm", value: { $0.algorithm } )
        }
    }
}
