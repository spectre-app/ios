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
          PasswordTypeItem(), SeparatorItem(),
          LoginTypeItem(), SeparatorItem(),
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
            self.color = self.model.preview.color
            self.image = self.model.preview.image
        }

        self.setNeedsUpdate()
    }

    // MARK: --- Types ---

    class PasswordCounterItem: StepperItem<MPService, UInt32> {
        init() {
            super.init( title: "Password Counter",
                        value: { $0.counter.rawValue }, update: { $0.counter = MPCounterValue( rawValue: $1 ) ?? .default },
                        step: 1, min: MPCounterValue.initial.rawValue, max: MPCounterValue.last.rawValue,
                        caption: { _ in
                            """
                            Increment the counter if you need to change the service's current password.
                            """
                        } )
        }
    }

    class PasswordTypeItem: PickerItem<MPService, MPResultType, MPResultTypeCell> {
        init() {
            super.init( track: .subject( "service", action: "resultType" ), title: "Password Type",
                        values: { _ in
                            [ MPResultType? ].joined(
                                    separator: [ nil ],
                                    MPResultType.recommendedTypes[.authentication],
                                    [ MPResultType.statefulPersonal ],
                                    MPResultType.allCases.filter { !$0.has( feature: .alternative ) } ).unique()
                        },
                        value: { $0.resultType }, update: { $0.resultType = $1 },
                        subitems: [ PasswordResultItem() ],
                        caption: {
                            let attacker = $0.user.attacker ?? .default
                            if InAppFeature.premium.isEnabled,
                               let timeToCrack = attacker.timeToCrack( type: $0.resultType ) ??
                                       attacker.timeToCrack( string: try? $0.result().token.await() ) {
                                return "Time to crack: \(timeToCrack) 🅿︎"
                            }
                            else {
                                return "Time to crack: unknown 🅿︎"
                            }
                        } )
        }

        override func populate(_ cell: MPResultTypeCell, indexPath: IndexPath, value: MPResultType) {
            cell.resultType = value
        }
    }

    class PasswordResultItem: FieldItem<MPService> {
        init() {
            super.init( title: nil, placeholder: "enter a password",
                        value: { try? $0.result().token.await() }, update: { service, password in
                MPTracker.shared.event( track: .subject( "service", action: "result", [
                    "type": "\(service.resultType)",
                    "entropy": MPAttacker.entropy( string: password ) ?? 0,
                ] ) )

                service.state( resultParam: password ).token.then {
                    do { service.resultState = try $0.get() }
                    catch { mperror( title: "Couldn't update service password", error: error ) }
                }
            } )
        }

        override func createItemView() -> FieldItemView {
            let view = super.createItemView()
            view.valueField => \.font => Theme.current.font.password
            view.valueField.autocapitalizationType = .none
            view.valueField.autocorrectionType = .no
            view.valueField.keyboardType = .asciiCapable
            return view
        }

        override func update() {
            super.update()

            (self.view as? FieldItemView)?.valueField.isEnabled = self.model?.resultType.in( class: .stateful ) ?? false
        }
    }

    class LoginTypeItem: PickerItem<MPService, MPResultType, MPResultTypeCell> {
        init() {
            super.init( track: .subject( "service", action: "loginType" ), title: "Login Name Type 🅿︎",
                        values: { _ in
                            [ MPResultType? ].joined(
                                    separator: [ nil ],
                                    [ MPResultType.none ],
                                    MPResultType.recommendedTypes[.identification],
                                    [ MPResultType.statefulPersonal ],
                                    MPResultType.allCases.filter { !$0.has( feature: .alternative ) } ).unique()
                        },
                        value: { $0.loginType }, update: { $0.loginType = $1 },
                        subitems: [ LoginResultItem() ],
                        caption: {
                            $0.loginType == .none ?
                                    "The service uses your Standard Login Name.":
                                    "The service is using a service‑specific login name."
                        } )

            self.addBehaviour( PremiumTapBehaviour() )
            self.addBehaviour( PremiumConditionalBehaviour( mode: .enables ) )
        }

        override func populate(_ cell: MPResultTypeCell, indexPath: IndexPath, value: MPResultType) {
            cell.resultType = value.nonEmpty

            if value == .none {
                cell.name = nil
                cell.class = "Standard Login"
            }
        }
    }

    class LoginResultItem: FieldItem<MPService> {
        let userButton = MPButton( track: .subject( "service.login", action: "user" ) )

        init() {
            super.init( title: nil, placeholder: "enter a login name",
                        value: { try? $0.result( keyPurpose: .identification ).token.await() },
                        update: { service, login in
                            MPTracker.shared.event( track: .subject( "service", action: "login", [
                                "type": "\(service.loginType)",
                                "entropy": MPAttacker.entropy( string: login ) ?? 0,
                            ] ) )

                            service.state( keyPurpose: .identification, resultParam: login ).token.then {
                                do { service.loginState = try $0.get() }
                                catch { mperror( title: "Couldn't update service name", error: error ) }
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
            view.valueField.leftView = MPMarginView( for: self.userButton, margins: .border( 4 ) )

            self.userButton.isRound = true
            self.userButton.action( for: .primaryActionTriggered ) { [unowned self] in
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

            self.userButton.title = self.model?.user.fullName.name( style: .abbreviated )
            self.userButton.sizeToFit()

            (self.view as? FieldItemView)?.valueField.leftViewMode = self.model?.loginType == MPResultType.none ? .always: .never
        }
    }

    class SecurityAnswerItem: ListItem<MPService, MPQuestion, SecurityAnswerItem.Cell> {
        init() {
            super.init( title: "Security Answers 🅿︎",
                        values: {
                            $0.questions.reduce( [ "": MPQuestion( service: $0, keyword: "" ) ] ) {
                                $0.merging( [ $1.keyword: $1 ], uniquingKeysWith: { $1 } )
                            }.values.sorted()
                        },
                        subitems: [
                            ButtonItem( track: .subject( "service.question", action: "add" ),
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

        override func populate(_ cell: Cell, indexPath: IndexPath, value: MPQuestion) {
            cell.question = value
        }

        override func delete(indexPath: IndexPath, value: MPQuestion) {
            trc( "Trashing security question: %@", value )

            self.model?.questions.removeAll { $0 === value }
        }

        class Cell: UITableViewCell {
            private let keywordLabel = UILabel()
            private let resultLabel  = UILabel()
            private lazy var copyButton = MPButton( track: .subject( "service.question", action: "copy",
                                                                     [ "words": self.question?.keyword.split( separator: " " ).count ?? 0 ] ),
                                                    title: "copy" )

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
                    self.question?.result().copy( fromView: self, trackingFrom: "service>details" )
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
                        value: { $0.url }, update: { $0.url = $1 } )
        }

        override func createItemView() -> FieldItemView {
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
