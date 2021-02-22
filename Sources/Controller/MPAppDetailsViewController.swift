//
// Created by Maarten Billemont on 2019-07-05.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit
import Countly

class MPAppDetailsViewController: MPItemsViewController<MPConfig>, MPConfigObserver, MPTrackerObserver {

    private var didBecomeActiveObserver: NSObjectProtocol?

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(focus: Item<MPConfig>.Type? = nil) {
        super.init( model: appConfig, focus: focus )
    }

    override func loadItems() -> [Item<MPConfig>] {
        [ VersionItem(), SeparatorItem(),
          Item<MPConfig>( subitems: [
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
        MPTracker.shared.observers.register( observer: self )
        self.didBecomeActiveObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil ) { [unowned self] _ in
            self.setNeedsUpdate()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear( animated )

        self.model.observers.unregister( observer: self )
        MPTracker.shared.observers.unregister( observer: self )
        self.didBecomeActiveObserver.flatMap { NotificationCenter.default.removeObserver( $0 ) }
    }

    // MARK: --- MPConfigObserver ---

    func didChangeConfig() {
        self.setNeedsUpdate()
    }

    // MARK: --- MPTrackerObserver ---

    func didChangeTracker() {
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
            super.init( track: .subject( "app", action: "diagnostics" ),
                        title: "Diagnostics", icon: { _ in .icon( "" ) },
                        value: { $0.diagnostics }, update: { $0.diagnostics = $1 }, caption: { _ in
                """
                Share anonymized issue information to enable quick resolution.
                """
            } )
        }
    }

    class NotificationsItem: ToggleItem<MPConfig> {
        init() {
            super.init( track: .subject( "app", action: "notifications" ),
                        title: "Notifications", icon: { _ in .icon( "" ) },
                        value: { _ in MPTracker.shared.enabledNotifications() }, update: {
                if $1 {
                    MPTracker.shared.enableNotifications()
                }
                else {
                    MPTracker.shared.disableNotifications()
                }
            }, caption: { _ in
                """
                Be notified of important events that may affect your online security.
                """
            } )
        }
    }

    class ThemeItem: PickerItem<MPConfig, Theme, ThemeItem.Cell> {
        init() {
            super.init( track: .subject( "app", action: "theme" ),
                        title: "Application Themes 🅿︎",
                        values: { _ in
                            [ Theme? ].joined(
                                    separator: [ nil ],
                                    [ .default ],
                                    Theme.allCases ).unique()
                        },
                        value: { Theme.with( path: $0.theme ) ?? .default }, update: { $0.theme = $1.path },
                        caption: { _ in Theme.current } )

            self.addBehaviour( PremiumTapBehaviour() )
            self.addBehaviour( PremiumConditionalBehaviour( mode: .enables ) )
        }

        override func populate(_ cell: Cell, indexPath: IndexPath, value: Theme) {
            cell.theme = value
        }

        class Cell: MPItemCell {
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

    class ManageSubscriptionItem: ButtonItem<MPConfig> {
        init() {
            super.init( track: .subject( "app", action: "subscription" ),
                        value: { _ in (label: "Premium Subscription", image: nil) }, action: { item in
                item.viewController?.show( MPPremiumDetailsViewController(), sender: item )
            } )
        }
    }

    class InfoItem: LinksItem<MPConfig> {
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
