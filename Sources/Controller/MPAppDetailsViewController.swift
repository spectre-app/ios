//
// Created by Maarten Billemont on 2019-07-05.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPAppDetailsViewController: MPDetailsViewController<MPConfig>, MPConfigObserver {

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init() {
        super.init( model: appConfig )

        self.model.observers.register( observer: self )
    }

    override func loadItems() -> [Item<MPConfig>] {
        [ VersionItem(), SeparatorItem(),
          Item<MPConfig>( subitems: [
              DiagnisticsItem(),
              ProItem(),
          ] ), SeparatorItem(),
          ThemeItem(), SeparatorItem( hidden: { _ in !appConfig.premium } ),
          LegacyItem(), SeparatorItem(),
          InfoItem() ]
    }

    // MARK: --- MPConfigObserver ---

    func didChangeConfig() {
        self.setNeedsUpdate()
    }

    // MARK: --- Types ---

    class VersionItem: LabelItem<MPConfig> {
        init() {
            super.init( title: "\(productName)",
                        value: { _ in Bundle.main.object( forInfoDictionaryKey: "CFBundleShortVersionString" ) },
                        caption: { _ in Bundle.main.object( forInfoDictionaryKey: "CFBundleVersion" ) as? String } )
        }
    }

    class DiagnisticsItem: ToggleItem<MPConfig> {
        init() {
            super.init(
                    identifier: "app >sendInfo",
                    title: "Diagnostics",
                    value: {
                        (icon: UIImage( named: "icon_bandage" ),
                         selected: $0.sendInfo,
                         enabled: true)
                    },
                    update: { $0.sendInfo = $1 },
                    caption: { _ in
                        """
                        Share anonymized issue information to enable quick resolution.
                        """
                    } )
        }
    }

    class ProItem: ToggleItem<MPConfig> {
        init() {
            super.init(
                    identifier: "app >premium",
                    title: """
                           Premium 🅿
                           """,
                    value: {
                        (icon: UIImage( named: "icon_manage" ),
                         selected: $0.premium,
                         enabled: true)
                    },
                    update: { $0.premium = $1 },
                    caption: { _ in
                        """
                        Unlock enhanced comfort and security features.
                        """
                    } )
        }
    }

    class ThemeItem: PickerItem<MPConfig, MPTheme> {
        init() {
            super.init(
                    identifier: "app >theme",
                    title: "Application Themes 🅿",
                    values: { _ in MPTheme.all },
                        value: { $0.theme },
                        update: { $0.theme = $1 },
                        caption: { _ in
                            """
                            Personalize the application's appearance.
                            """
                        },
                        hidden: { !$0.premium } )
        }

        override func didLoad(collectionView: UICollectionView) {
            collectionView.register( Cell.self )
        }

        override func cell(collectionView: UICollectionView, indexPath: IndexPath, model: MPConfig, value: MPTheme) -> UICollectionViewCell? {
            Cell.dequeue( from: collectionView, indexPath: indexPath ) {
                ($0 as? Cell)?.theme = value
            }
        }

        class Cell: MPItemCell {
            weak var theme: MPTheme? = MPTheme.default {
                didSet {
                    DispatchQueue.main.perform {
                        self.effectView.contentView.backgroundColor = self.theme?.color.backdrop.get()
                    }
                }
            }
        }
    }

    class LegacyItem: Item<MPConfig> {
        init() {
            super.init( title: "Legacy Data",
                        subitems: [
                            ButtonItem<MPConfig>( identifier: "app.legacy #re-import", value: { _ in (label: "Re-import", image: nil) } ) { _ in
                                MPMarshal.shared.importLegacy( force: true )
                            },
                            ButtonItem<MPConfig>( identifier: "app.legacy #clean", value: { _ in (label: "Clean up", image: nil) } ) { _ in
                                // TODO: purge legacy data
                            }
                        ],
                        caption: { _ in
                            """
                            User information from an older version of the app exists.
                            You can leave it untouched or clean up to remove it.
                            """
                        },
                        hidden: { !$0.hasLegacy } )
        }
    }

    class InfoItem: ListItem<MPConfig, InfoItem.Link> {
        init() {
            super.init( title: "Links", values: { _ in
                [
                    Link( title: "Home", url: URL( string: "https://masterpassword.app" ) ),
                    Link( title: "Support", url: URL( string: "http://help.masterpasswordapp.com" ) ),
                    Link( title: "White Paper", url: URL( string: "https://masterpassword.app/masterpassword-algorithm.pdf" ) ),
                    Link( title: "Source Portal", url: URL( string: "https://gitlab.com/MasterPassword/MasterPassword" ) ),
                ]
            } )
        }

        override func didLoad(tableView: UITableView) {
            tableView.register( Cell.self )
        }

        override func cell(tableView: UITableView, indexPath: IndexPath, model: MPConfig, value: Link) -> UITableViewCell? {
            Cell.dequeue( from: tableView, indexPath: indexPath ) {
                ($0 as? Cell)?.link = value
            }
        }

        struct Link: Hashable {
            let title: String
            let url:   URL?
        }

        class Cell: UITableViewCell {
            var link: Link? {
                didSet {
                    DispatchQueue.main.perform {
                        self.button.setTitle( self.link?.title, for: .normal )
                    }
                }
            }

            private let button = UIButton()

            // MARK: --- Life ---

            required init?(coder aDecoder: NSCoder) {
                fatalError( "init(coder:) is not supported for this class" )
            }

            override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
                super.init( style: style, reuseIdentifier: reuseIdentifier )

                // - View
                self.isOpaque = false
                self.backgroundColor = .clear

                self.button.setTitleColor( appConfig.theme.color.body.get(), for: .normal )
                self.button.setTitleShadowColor( appConfig.theme.color.shadow.get(), for: .normal )
                self.button.titleLabel?.shadowOffset = CGSize( width: 0, height: 1 )
                self.button.titleLabel?.font = appConfig.theme.font.callout.get()
                self.button.action( for: .primaryActionTriggered ) { [unowned self] in
                    if let url = self.link?.url {
                        trc( "Opening link: %@", url )

                        UIApplication.shared.openURL( url )
                    }
                }

                // - Hierarchy
                self.contentView.addSubview( self.button )

                // - Layout
                LayoutConfiguration( view: self.button )
                        .constrain()
                        .activate()
            }
        }
    }
}
