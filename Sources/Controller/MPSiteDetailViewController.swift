//
// Created by Maarten Billemont on 2018-10-15.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation
import UIKit

class MPSiteDetailViewController: UIViewController, MPSiteObserver {
    let observers = Observers<MPSiteDetailObserver>()
    let site: MPSite

    let items = [ PasswordCounterItem(), SeparatorItem(),
                  PasswordTypeItem(), SeparatorItem(),
                  LoginTypeItem(), SeparatorItem(),
                  URLItem(), SeparatorItem(),
                  InfoItem() ]

    let backgroundView = UIView()
    let itemsView      = UIStackView()
    let closeButton    = MPButton.closeButton()

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(site: MPSite) {
        self.site = site
        super.init( nibName: nil, bundle: nil )

        self.site.observers.register( self ).siteDidChange( self.site )
    }

    override func viewDidLoad() {

        // - View
        self.backgroundView.layer.cornerRadius = 8
        self.backgroundView.layer.shadowRadius = 8
        self.backgroundView.layer.shadowOpacity = 0.382

        self.itemsView.axis = .vertical
        self.itemsView.spacing = 20
        for item in self.items {
            self.itemsView.addArrangedSubview( item.view )
        }

        self.closeButton.button.addAction( for: .touchUpInside ) { _, _ in
            self.observers.notify { $0.siteDetailShouldDismiss() }
        }

        // - Hierarchy
        self.backgroundView.addSubview( self.itemsView )
        self.view.addSubview( self.backgroundView )
        self.view.addSubview( self.closeButton )

        // - Layout
        ViewConfiguration( view: self.backgroundView )
                .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.bottomAnchor ) }
                .activate()
        ViewConfiguration( view: self.itemsView )
                .constrainToSuperview( withMargins: true, anchor: .vertically )
                .constrainToSuperview( withMargins: false, anchor: .horizontally )
                .activate()
        ViewConfiguration( view: self.closeButton )
                .constrainTo { $1.centerXAnchor.constraint( equalTo: self.backgroundView.centerXAnchor ) }
                .constrainTo { $1.centerYAnchor.constraint( equalTo: self.backgroundView.bottomAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                .activate()
    }

    // MARK: --- MPSiteObserver ---

    func siteDidChange(_ site: MPSite) {
        DispatchQueue.main.perform {
            self.backgroundView.backgroundColor = self.site.color

            for item in self.items {
                item.site = self.site
            }
        }
    }

    // MARK: --- Types ---

    class PasswordCounterItem: StepperItem<UInt32> {
        init() {
            super.init( title: "Password Counter",
                        itemValue: { $0.counter.rawValue },
                        itemUpdate: { $0.counter = MPCounterValue( rawValue: $1 ) ?? .default },
                        step: 1, min: MPCounterValue.initial.rawValue, max: MPCounterValue.last.rawValue )
        }
    }

    class PasswordTypeItem: PickerItem<MPResultType> {
        init() {
            super.init( title: "Password Type", values: [ MPResultType ]( MPResultTypes ),
                        itemValue: { $0.resultType },
                        itemUpdate: { $0.resultType = $1 },
                        itemCell: { collectionView, indexPath, type in
                            return MPResultTypeCell.dequeue( from: collectionView, indexPath: indexPath ) {
                                ($0 as! MPResultTypeCell).resultType = type
                            }
                        } ) {
                $0.registerCell( MPResultTypeCell.self )
            }
        }
    }

    class LoginTypeItem: PickerItem<MPResultType> {
        init() {
            super.init( title: "Login Type", values: [ MPResultType ]( MPResultTypes ),
                        itemValue: { $0.loginType },
                        itemUpdate: { $0.loginType = $1 },
                        itemCell: { collectionView, indexPath, type in
                            return MPResultTypeCell.dequeue( from: collectionView, indexPath: indexPath ) {
                                ($0 as! MPResultTypeCell).resultType = type
                            }
                        } ) {
                $0.registerCell( MPResultTypeCell.self )
            }
        }
    }

    class URLItem: TextItem {
        init() {
            super.init( title: "URL", placeholder: "eg. https://www.apple.com",
                        itemValue: { $0.url },
                        itemUpdate: { $0.url = $1 } )
        }

        override func createItemView() -> TextItemView {
            let itemView = super.createItemView()
            itemView.valueField.autocapitalizationType = .none
            itemView.valueField.autocorrectionType = .no
            itemView.valueField.keyboardType = .URL
            return itemView
        }
    }

    class InfoItem: Item {
        init() {
            super.init( title: nil, subitems: [
                UsesItem(),
                UsedItem(),
                AlgorithmItem(),
            ] )
        }
    }

    class UsesItem: LabelItem {
        init() {
            super.init( title: "Total Uses" ) { "\($0.uses)" }
        }
    }

    class UsedItem: DateItem {
        init() {
            super.init( title: "Last Used" ) { $0.lastUsed }
        }
    }

    class AlgorithmItem: LabelItem {
        init() {
            super.init( title: "Algorithm" ) { "v\($0.algorithm.rawValue)" }
        }
    }
}

@objc
protocol MPSiteDetailObserver {
    func siteDetailShouldDismiss()
}
