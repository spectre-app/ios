//
// Created by Maarten Billemont on 2019-07-05.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit
import Countly

class MPAppDetailsViewController: MPDetailsViewController<MPConfig>, MPConfigObserver {

    private var didBecomeActiveObserver: NSObjectProtocol?

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init() {
        super.init( model: appConfig )

        self.model.observers.register( observer: self )

        self.didBecomeActiveObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil ) { _ in
            self.setNeedsUpdate()
        }
    }

    deinit {
        self.didBecomeActiveObserver.flatMap { NotificationCenter.default.removeObserver( $0 ) }
    }

    override func loadItems() -> [Item<MPConfig>] {
        [ VersionItem(), SeparatorItem(),
          Item<MPConfig>( subitems: [
              DiagnosticsItem(),
              NotificationsItem(),
          ] ),
          Item<MPConfig>( subitems: [
              PremiumItem(),
          ] ), SeparatorItem(),
          ThemeItem(), SeparatorItem( hidden: { _ in !appConfig.premium } ),
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

    class DiagnosticsItem: ToggleItem<MPConfig> {
        init() {
            super.init(
                    identifier: "app >diagnostics",
                    title: "Diagnostics",
                    value: {
                        (icon: UIImage.icon( "" ),
                         selected: $0.diagnostics,
                         enabled: true)
                    },
                    update: { $0.diagnostics = $1 },
                    caption: { _ in
                        """
                        Share anonymized issue information to enable quick resolution.
                        """
                    } )
        }
    }

    class NotificationsItem: ToggleItem<MPConfig> {
        init() {
            super.init(
                    identifier: "app >notifications",
                    title: "Notifications",
                    value: { _ in
                        (icon: UIImage.icon( "" ),
                         selected: MPTracker.enabledNotifications(),
                         enabled: true)
                    },
                    update: {
                        if $1 {
                            MPTracker.enableNotifications()
                        }
                        else {
                            MPTracker.disableNotifications()
                        }
                    },
                    caption: { _ in
                        """
                        Be notified of important events that may affect your online security.
                        """
                    } )
        }
    }

    class PremiumItem: ToggleItem<MPConfig> {
        init() {
            super.init(
                    identifier: "app >premium",
                    title: """
                           Premium 🅿
                           """,
                    value: {
                        (icon: UIImage.icon( "" ),
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

    class ThemeItem: PickerItem<MPConfig, Theme> {
        init() {
            super.init(
                    identifier: "app >theme",
                    title: "Application Themes 🅿",
                    values: { _ in Theme.all },
                    value: { Theme.with( path: $0.theme ) ?? .default },
                    update: { $0.theme = $1.path },
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

        override func cell(collectionView: UICollectionView, indexPath: IndexPath, model: MPConfig, value: Theme) -> UICollectionViewCell? {
            Cell.dequeue( from: collectionView, indexPath: indexPath ) {
                ($0 as? Cell)?.theme = value
            }
        }

        class Cell: MPItemCell {
            weak var theme: Theme? = Theme.default {
                didSet {
                    DispatchQueue.main.perform {
                        self.effectView.contentView => \.backgroundColor => self.theme?.color.backdrop
                    }
                }
            }
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

                self.button => \.titleLabel!.font => Theme.current.font.callout
                self.button => \.currentTitleColor => Theme.current.color.body
                self.button => \.currentTitleShadowColor => Theme.current.color.shadow
                self.button.titleLabel!.shadowOffset = CGSize( width: 0, height: 1 )
                self.button.action( for: .primaryActionTriggered ) { [unowned self] in
                    if let url = self.link?.url {
                        trc( "Opening link: %@", url )

                        UIApplication.shared.open( url )
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
