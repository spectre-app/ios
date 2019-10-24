//
// Created by Maarten Billemont on 2019-07-05.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPAppDetailsViewController: MPDetailsViewController<Void> {

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init() {
        super.init( model: Void() )
    }

    override func loadItems() -> [Item<Void>] {
        [ VersionItem(), SeparatorItem(),
          DiagnisticsItem(), LegacyItem(), SeparatorItem(),
          InfoItem() ]
    }

    // MARK: --- Types ---

    class VersionItem: LabelItem<Void> {
        init() {
            super.init( title: "\(PearlInfoPlist.get().cfBundleDisplayName ?? productName)",
                        value: { _ in PearlInfoPlist.get().cfBundleShortVersionString },
                        caption: { _ in PearlInfoPlist.get().cfBundleVersion } )
        }
    }

    class DiagnisticsItem: ToggleItem<Void> {
        init() {
            super.init( title: "Diagnostics", value: { _ in
                (UserDefaults.standard.bool( forKey: "sendInfo" ), UIImage( named: "icon_bandage" ))
            }, caption: { _ in
                """
                Share anonymized issue information to enable quick resolution.
                """
            } ) { _, sendInfo in
                UserDefaults.standard.set( sendInfo, forKey: "sendInfo" )
            }
        }
    }

    class LegacyItem: ButtonItem<Void> {
        init() {
            super.init( title: "Legacy Data", value: { _ in
                (label: "Re-Import Legacy Users", image: nil)
            } ) { _ in
                MPMarshal.shared.importLegacy( force: true )
            }

            self.hidden = true
            MPMarshal.shared.hasLegacy().then { self.hidden = !$0 }
        }
    }

    class InfoItem: ListItem<Void, InfoItem.Link> {
        init() {
            super.init( title: "Links", values: {
                [
                    Link( title: "Home", url: URL( string: "https://masterpassword.app" ) ),
                    Link( title: "Support", url: URL( string: "http://help.masterpasswordapp.com" ) ),
                    Link( title: "White Paper", url: URL( string: "https://masterpassword.app/masterpassword-algorithm.pdf" ) ),
                    Link( title: "Source Portal", url: URL( string: "https://gitlab.com/MasterPassword/MasterPassword" ) ),
                ]
            } )
        }

        override func didLoad(tableView: UITableView) {
            tableView.registerCell( Cell.self )
        }

        override func cell(tableView: UITableView, indexPath: IndexPath, model: (), value: Link) -> UITableViewCell? {
            Cell.dequeue( from: tableView, indexPath: indexPath ) {
                ($0 as? Cell)?.set( title: value.title ) {
                    if let url = value.url {
                        UIApplication.shared.openURL( url )
                    }
                }
            }
        }

        struct Link: Hashable {
            let title: String
            let url:   URL?
        }

        class Cell: UITableViewCell {
            private let button = UIButton()
            private var action: (() -> Void)?

            required init?(coder aDecoder: NSCoder) {
                fatalError( "init(coder:) is not supported for this class" )
            }

            override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
                super.init( style: style, reuseIdentifier: reuseIdentifier )

                // - View
                self.isOpaque = false
                self.backgroundColor = .clear

                self.button.setTitleColor( MPTheme.global.color.body.get(), for: .normal )
                self.button.setTitleShadowColor( MPTheme.global.color.shadow.get(), for: .normal )
                self.button.titleLabel?.shadowOffset = CGSize( width: 0, height: 1 )
                self.button.titleLabel?.font = MPTheme.global.font.callout.get()
                self.button.addAction( for: .touchUpInside ) { _, _ in
                    self.action?()
                }

                // - Hierarchy
                self.contentView.addSubview( self.button )

                // - Layout
                LayoutConfiguration( view: self.button )
                        .constrainToOwner()
                        .activate()
            }

            func set(title: String?, action: @escaping () -> Void) {
                self.action = action
                self.button.setTitle( title, for: .normal )
            }
        }
    }
}
