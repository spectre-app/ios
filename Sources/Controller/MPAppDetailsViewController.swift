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
            super.init( title: "\(PearlInfoPlist.get().cfBundleDisplayName ?? productName)" ) { _ in
                (PearlInfoPlist.get().cfBundleShortVersionString, PearlInfoPlist.get().cfBundleVersion)
            }
        }
    }

    class DiagnisticsItem: ToggleItem<Void> {
        init() {
            super.init( title: "Diagnostics", caption:
            """
            Share anonymized issue information to enable quick resolution.
            """, itemValue: { _ in
                (UserDefaults.standard.bool( forKey: "sendInfo" ), UIImage( named: "icon_bandage" ))
            } ) { _, sendInfo in
                UserDefaults.standard.set( sendInfo, forKey: "sendInfo" )
            }
        }
    }

    class LegacyItem: ButtonItem<Void> {
        init() {
            super.init( title: "Legacy Data", itemValue: { _ in
                ("Re-Import Legacy Users", nil)
            } ) { _ in
                MPMarshal.shared.importLegacy( force: true )
            }

            self.hidden = true
            MPMarshal.shared.hasLegacy().then { self.hidden = !$0 }
        }
    }

    class InfoItem: ListItem<Void, (title: String, url: URL?)> {

        init() {
            super.init( title: "Links", values: [
                (title: "Home", url: URL( string: "https://masterpassword.app" )),
                (title: "Support", url: URL( string: "http://help.masterpasswordapp.com" )),
                (title: "White Paper", url: URL( string: "https://masterpassword.app/masterpassword-algorithm.pdf" )),
                (title: "Source Portal", url: URL( string: "https://gitlab.com/MasterPassword/MasterPassword" )),
            ], itemCell: { tableView, indexPath, value in
                InfoCell.dequeue( from: tableView, indexPath: indexPath ) {
                    ($0 as? InfoCell)?.set( title: value.title ) {
                        if let url = value.url {
                            UIApplication.shared.openURL( url )
                        }
                    }
                }
            } ) { tableView in
                tableView.registerCell( InfoCell.self )
            }
        }

        class InfoCell: UITableViewCell {
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
