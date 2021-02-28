//
// Created by Maarten Billemont on 2019-07-05.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit
import Countly

class DetailAppViewController: ItemsViewController<AppConfig>, AppConfigObserver, TrackerObserver {

    private var didBecomeActiveObserver: NSObjectProtocol?

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(focus: Item<AppConfig>.Type? = nil) {
        super.init( model: AppConfig.shared, focus: focus )
    }

    override func loadItems() -> [Item<AppConfig>] {
        [ VersionItem(), SeparatorItem(),
          Item<AppConfig>( subitems: [
              DiagnosticsItem(),
              NotificationsItem(),
          ] ), SeparatorItem(),
          ThemeItem(),
          ManageSubscriptionItem(), SeparatorItem(),
          InfoItem() ]
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear( animated )

        self.model.observers.register( observer: self )
        Tracker.shared.observers.register( observer: self )
        self.didBecomeActiveObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil ) { [unowned self] _ in
            self.setNeedsUpdate()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear( animated )

        self.model.observers.unregister( observer: self )
        Tracker.shared.observers.unregister( observer: self )
        self.didBecomeActiveObserver.flatMap { NotificationCenter.default.removeObserver( $0 ) }
    }

    // MARK: --- AppConfigObserver ---

    func didChangeConfig() {
        self.setNeedsUpdate()
    }

    // MARK: --- TrackerObserver ---

    func didChangeTracker() {
        self.setNeedsUpdate()
    }

    // MARK: --- Types ---

    class VersionItem: LabelItem<AppConfig> {
        init() {
            super.init( title: "\(productName)",
                        value: { _ in Bundle.main.object( forInfoDictionaryKey: "CFBundleShortVersionString" ) },
                        caption: { _ in Bundle.main.object( forInfoDictionaryKey: "CFBundleVersion" ) as? String } )
        }
    }

    class DiagnosticsItem: ToggleItem<AppConfig> {
        init() {
            super.init( track: .subject( "app", action: "diagnostics" ),
                        title: "Diagnostics", icon: { _ in .icon( "" ) },
                        value: { $0.diagnostics }, update: { $0.model?.diagnostics = $1 }, caption: { _ in
                """
                Share anonymized issue information to enable quick resolution.
                """
            } )
        }
    }

    class NotificationsItem: ToggleItem<AppConfig> {
        init() {
            super.init( track: .subject( "app", action: "notifications" ),
                        title: "Notifications", icon: { _ in .icon( "" ) },
                        value: { _ in Tracker.shared.enabledNotifications() }, update: {
                if $1 {
                    Tracker.shared.enableNotifications()
                }
                else {
                    Tracker.shared.disableNotifications()
                }
            }, caption: { _ in
                """
                Be notified of important events that may affect your online security.
                """
            } )
        }
    }

    class ThemeItem: PickerItem<AppConfig, Theme, ThemeItem.Cell> {
        init() {
            super.init( track: .subject( "app", action: "theme" ),
                        title: "Application Themes 🅿︎",
                        values: { _ in
                            [ Theme? ].joined(
                                    separator: [ nil ],
                                    [ .default ],
                                    Theme.allCases ).unique()
                        },
                        value: { Theme.with( path: $0.theme ) ?? .default }, update: { $0.model?.theme = $1.path },
                        caption: { _ in Theme.current } )

            self.addBehaviour( PremiumTapBehaviour() )
            self.addBehaviour( PremiumConditionalBehaviour( mode: .enables ) )
        }

        override func populate(_ cell: Cell, indexPath: IndexPath, value: Theme) {
            cell.theme = value
        }

        class Cell: EffectCell {
            weak var theme: Theme? = Theme.default {
                didSet {
                    DispatchQueue.main.perform {
                        self.effectView => \.borderColor => self.theme?.color.secondary
                        self.effectView => \.backgroundColor => self.theme?.color.panel
                    }
                }
            }
        }
    }

    class ManageSubscriptionItem: ButtonItem<AppConfig> {
        init() {
            super.init( track: .subject( "app", action: "subscription" ),
                        value: { _ in (label: "Premium Subscription", image: nil) }, action: { item in
                item.viewController?.show( DetailPremiumViewController(), sender: item )
            } )
        }
    }

    class InfoItem: LinksItem<AppConfig> {
        init() {
            super.init( title: "Links", values: { _ in
                [
                    Link( title: "Home", url: URL( string: "https://spectre.app" ) ),
                    Link( title: "Support", url: URL( string: "http://support.spectre.app" ) ),
                    Link( title: "White Paper", url: URL( string: "https://spectre.app/Spectre-algorithm.pdf" ) ),
                    Link( title: "Source Portal", url: URL( string: "https://source.spectre.app" ) ),
                ]
            } )
        }
    }
}
