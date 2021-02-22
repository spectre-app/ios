//
// Created by Maarten Billemont on 2018-10-15.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation
import UIKit

class DetailSiteViewController: ItemsViewController<Site>, SiteObserver {

    // MARK: --- Life ---

    override func loadItems() -> [Item<Site>] {
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

    override init(model: Site, focus: Item<Site>.Type? = nil) {
        super.init( model: model, focus: focus )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear( animated )

        self.model.observers.register( observer: self )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear( animated )

        self.model.observers.unregister( observer: self )
    }

    override func update() {
        self.color = self.model.preview.color
        self.image = self.model.preview.image

        super.update()
    }

    // MARK: --- SiteObserver ---

    func siteDidChange(_ site: Site) {
        self.setNeedsUpdate()
    }

    // MARK: --- Types ---

    class PasswordCounterItem: StepperItem<Site, UInt32> {
        init() {
            super.init( title: "Password Counter",
                        value: { $0.counter.rawValue }, update: { $0.counter = MPCounterValue( rawValue: $1 ) ?? .default },
                        step: 1, min: MPCounterValue.initial.rawValue, max: MPCounterValue.last.rawValue,
                        caption: { _ in
                            """
                            Increment the counter if you need to change the site's current password.
                            """
                        } )
        }
    }

    class PasswordTypeItem: PickerItem<Site, MPResultType, EffectResultTypeCell> {
        init() {
            super.init( track: .subject( "site", action: "resultType" ), title: "Password Type",
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

        override func populate(_ cell: EffectResultTypeCell, indexPath: IndexPath, value: MPResultType) {
            cell.resultType = value
        }
    }

    class PasswordResultItem: FieldItem<Site> {
        init() {
            super.init( title: nil, placeholder: "enter a password",
                        value: { try? $0.result().token.await() }, update: { site, password in
                Tracker.shared.event( track: .subject( "site", action: "result", [
                    "type": "\(site.resultType)",
                    "entropy": Attacker.entropy( string: password ) ?? 0,
                ] ) )

                site.state( resultParam: password ).token.then {
                    do { site.resultState = try $0.get() }
                    catch { mperror( title: "Couldn't update site password", error: error ) }
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

    class LoginTypeItem: PickerItem<Site, MPResultType, EffectResultTypeCell> {
        init() {
            super.init( track: .subject( "site", action: "loginType" ), title: "Login Name Type 🅿︎",
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
                                    "The site uses your Standard Login Name.":
                                    "The site is using a site‑specific login name."
                        } )

            self.addBehaviour( PremiumTapBehaviour() )
            self.addBehaviour( PremiumConditionalBehaviour( mode: .enables ) )
        }

        override func populate(_ cell: EffectResultTypeCell, indexPath: IndexPath, value: MPResultType) {
            cell.resultType = value.nonEmpty

            if value == .none {
                cell.name = nil
                cell.class = "Standard Login"
            }
        }
    }

    class LoginResultItem: FieldItem<Site> {
        let userButton = EffectButton( track: .subject( "site.login", action: "user" ) )

        init() {
            super.init( title: nil, placeholder: "enter a login name",
                        value: { try? $0.result( keyPurpose: .identification ).token.await() },
                        update: { site, login in
                            Tracker.shared.event( track: .subject( "site", action: "login", [
                                "type": "\(site.loginType)",
                                "entropy": Attacker.entropy( string: login ) ?? 0,
                            ] ) )

                            site.state( keyPurpose: .identification, resultParam: login ).token.then {
                                do { site.loginState = try $0.get() }
                                catch { mperror( title: "Couldn't update site name", error: error ) }
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
            view.valueField.leftView = MarginView( for: self.userButton, margins: .border( 4 ) )

            self.userButton.isRound = true
            self.userButton.action( for: .primaryActionTriggered ) { [unowned self] in
                if let user = self.model?.user, self.model?.loginType == MPResultType.none {
                    self.viewController?.show(
                            DetailUserViewController( model: user, focus: DetailUserViewController.LoginTypeItem.self ), sender: self )
                }
            }

            return view
        }

        override func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
            super.textFieldShouldBeginEditing( textField ) && (self.model?.loginType.in( class: .stateful ) ?? false)
        }

        override func update() {
            super.update()

            self.userButton.title = self.model?.user.userName.name( style: .abbreviated )
            self.userButton.sizeToFit()

            (self.view as? FieldItemView)?.valueField.leftViewMode = self.model?.loginType == MPResultType.none ? .always: .never
        }
    }

    class SecurityAnswerItem: ListItem<Site, Question, SecurityAnswerItem.Cell> {
        init() {
            super.init( title: "Security Answers 🅿︎",
                        values: {
                            $0.questions.reduce( [ "": Question( site: $0, keyword: "" ) ] ) {
                                $0.merging( [ $1.keyword: $1 ], uniquingKeysWith: { $1 } )
                            }.values.sorted()
                        },
                        subitems: [
                            ButtonItem( track: .subject( "site.question", action: "add" ),
                                        value: { _ in (label: "Add Security Question", image: nil) },
                                        action: { item in
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
                                                guard let site = item?.model, let keyword = controller?.textFields?.first?.text?.nonEmpty
                                                else { return }

                                                trc( "Adding security question <%@> for: %@", keyword, site )
                                                site.questions.append( Question( site: site, keyword: keyword ) )
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

        override func populate(_ cell: Cell, indexPath: IndexPath, value: Question) {
            cell.question = value
        }

        override func delete(indexPath: IndexPath, value: Question) {
            trc( "Trashing security question: %@", value )

            self.model?.questions.removeAll { $0 === value }
        }

        class Cell: UITableViewCell {
            private let keywordLabel = UILabel()
            private let resultLabel  = UILabel()
            private lazy var copyButton = EffectButton( track: .subject( "site.question", action: "copy",
                                                                         [ "words": self.question?.keyword.split( separator: " " ).count ?? 0 ] ),
                                                        title: "copy" )

            weak var question: Question? {
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
                    self.question?.result().copy( fromView: self, trackingFrom: "site>details" )
                }

                // - Hierarchy
                self.contentView.addSubview( self.keywordLabel )
                self.contentView.addSubview( self.resultLabel )
                self.contentView.addSubview( self.copyButton )

                // - Layout
                LayoutConfiguration( view: self.resultLabel )
                        .constrain { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                        .constrain { $1.topAnchor.constraint( lessThanOrEqualTo: $0.layoutMarginsGuide.topAnchor ) }
                        .activate()
                LayoutConfiguration( view: self.keywordLabel )
                        .constrain { $1.topAnchor.constraint( equalTo: self.resultLabel.bottomAnchor ) }
                        .constrain { $1.leadingAnchor.constraint( equalTo: self.resultLabel.leadingAnchor ) }
                        .constrain { $1.trailingAnchor.constraint( equalTo: self.resultLabel.trailingAnchor ) }
                        .constrain { $1.bottomAnchor.constraint( equalTo: $0.layoutMarginsGuide.bottomAnchor ) }
                        .activate()
                LayoutConfiguration( view: self.copyButton )
                        .constrain { $1.topAnchor.constraint( greaterThanOrEqualTo: $0.layoutMarginsGuide.topAnchor ) }
                        .constrain { $1.leadingAnchor.constraint( equalTo: self.resultLabel.trailingAnchor, constant: 8 ) }
                        .constrain { $1.centerYAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerYAnchor ) }
                        .constrain { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                        .constrain { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.layoutMarginsGuide.bottomAnchor ) }
                        .activate()
            }
        }
    }

    class URLItem: FieldItem<Site> {
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

    class InfoItem: Item<Site> {
        init() {
            super.init( title: nil, subitems: [
                UsesItem(),
                UsedItem(),
                AlgorithmItem(),
            ] )
        }
    }

    class UsesItem: LabelItem<Site> {
        init() {
            super.init( title: "Total Uses", value: { $0.uses } )
        }
    }

    class UsedItem: DateItem<Site> {
        init() {
            super.init( title: "Last Used", value: { $0.lastUsed } )
        }
    }

    class AlgorithmItem: LabelItem<Site> {
        init() {
            super.init( title: "Algorithm", value: { $0.algorithm } )
        }
    }
}
