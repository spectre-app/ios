// =============================================================================
// Created by Maarten Billemont on 2019-07-05.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import UIKit
import Countly

class DetailAppViewController: ItemsViewController<AppConfig>, AppConfigObserver, TrackerObserver {

    private var didBecomeActiveObserver: NSObjectProtocol?

    // MARK: - Life

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(focus: Item<AppConfig>.Type? = nil) {
        super.init( model: AppConfig.shared, focus: focus )
    }

    override func loadItems() -> [Item<AppConfig>] {
        [ VersionItem(), SeparatorItem(),

          Item<AppConfig>( subitems: [
              Item<AppConfig>( subitems: [
                  DiagnosticsItem(),
                  NotificationsItem(),
              ] ), Item<AppConfig>( subitems: [
                  HandoffItem(),
                  OfflineItem(),
              ] ),
              LinksItem<AppConfig>( values: { _ in
                  [
                      .init( title: "Privacy Policy", url: URL( string: "https://spectre.app/policy/privacy/" ) ),
                  ]
              } ),
          ], axis: .vertical ),
          SeparatorItem(),

          Item<AppConfig>( subitems: [
              ThemeItem(),
              LogoItem(),
              ColorfulSitesItem(),
              ManageSubscriptionItem(),
          ], axis: .vertical ),
          SeparatorItem(),

          LinksItem<AppConfig>( title: "Links", values: { _ in
              [
                  .init( title: "Home", url: URL( string: "https://spectre.app" ) ),
                  .init( title: "Questions", url: URL( string: "http://chat.spectre.app" ) ),
                  .init( title: "White Paper", url: URL( string: "https://spectre.app/spectre-algorithm.pdf" ) ),
                  .init( title: "Source Portal", url: URL( string: "https://source.spectre.app" ) ),
              ]
          } ),
        ]
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

    // MARK: - AppConfigObserver

    func didChange(appConfig: AppConfig, at change: PartialKeyPath<AppConfig>) {
        self.setNeedsUpdate()
    }

    // MARK: - TrackerObserver

    func didChange(tracker: Tracker) {
        self.setNeedsUpdate()
    }

    // MARK: - Types

    class VersionItem: LabelItem<AppConfig> {
        init() {
            super.init( title: "\(productName)",
                        value: { _ in Bundle.main.object( forInfoDictionaryKey: "CFBundleShortVersionString" ) },
                        caption: { _ in (Bundle.main.object( forInfoDictionaryKey: "CFBundleVersion" ) as? String).flatMap { "\($0)" } } )
        }
    }

    class DiagnosticsItem: ToggleItem<AppConfig> {
        init() {
            super.init( track: .subject( "app", action: "diagnostics" ),
                        title: "Diagnostics", icon: { _ in .icon( "???" ) },
                        value: { $0.diagnostics && !$0.offline }, update: { $0.model?.diagnostics = $1 }, caption: { _ in
                """
                Share anonymized issue information to enable quick resolution.
                """
            } )

            self.addBehaviour( ConditionalBehaviour( effect: .enables ) { !$0.offline } )
        }
    }

    class NotificationsItem: ToggleItem<AppConfig> {
        init() {
            super.init( track: .subject( "app", action: "notifications" ),
                        title: "Notifications", icon: { _ in .icon( "???" ) },
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

    class ColorfulSitesItem: ToggleItem<AppConfig> {
        init() {
            super.init( track: .subject( "app", action: "themeSites" ),
                        title: "Colorful Sites", icon: { _ in .icon( "????" ) },
                        value: { $0.colorfulSites }, update: {
                $0.model?.colorfulSites = $1
            }, caption: { _ in
                """
                Colorize the theme using the look and feel of your sites.
                """
            } )
        }
    }

    class HandoffItem: ToggleItem<AppConfig> {
        init() {
            super.init( track: .subject( "app", action: "handoff" ),
                        title: "Handoff ???????", icon: { _ in .icon( "???" ) },
                        value: { $0.allowHandoff }, update: {
                $0.model?.allowHandoff = $1
            }, caption: { _ in
                """
                Allow sharing of copied values through Apple's Universal Clipboard.
                """
            } )

            self.addBehaviour( PremiumTapBehaviour() )
            self.addBehaviour( PremiumConditionalBehaviour( effect: .enables ) )
        }
    }

    class OfflineItem: ToggleItem<AppConfig> {
        init() {
            super.init( track: .subject( "app", action: "offline" ),
                        title: "Offline Mode", icon: { _ in .icon( "???" ) },
                        value: { $0.offline }, update: {
                $0.model?.offline = $1
            }, caption: { _ in
                """
                Run fully disconnected, turning off any features that use the Internet.
                """
            } )
        }
    }

    class ThemeItem: PickerItem<AppConfig, Theme, ThemeItem.Cell> {
        init() {
            super.init( track: .subject( "app", action: "theme" ),
                        title: "Application Themes ???????",
                        values: { _ in
                            [ Theme? ].joined(
                                    separator: [ nil ],
                                    [ .default ],
                                    Theme.allCases ).unique()
                        },
                        value: { Theme.with( path: $0.theme ) ?? .default }, update: { $0.model?.theme = $1.path },
                        caption: { _ in "\(Theme.current)" } )

            self.addBehaviour( PremiumTapBehaviour() )
            self.addBehaviour( PremiumConditionalBehaviour( effect: .enables ) )
        }

        override func populate(_ cell: Cell, indexPath: IndexPath, value: Theme) {
            cell.theme = value
        }

        class Cell: EffectCell {
            let iconView = UIImageView( image: .icon( "???" ) )
            override var isSelected: Bool {
                didSet {
                    self.iconView.isHidden = !self.isSelected
                }
            }
            weak var theme: Theme? = Theme.default {
                didSet {
                    DispatchQueue.main.perform {
                        self.effectView => \.borderColor => self.theme?.color.secondary
                        self.effectView => \.backgroundColor => self.theme?.color.backdrop
                    }
                }
            }

            required init?(coder aDecoder: NSCoder) {
                fatalError( "init(coder:) is not supported for this class" )
            }

            override init(frame: CGRect) {
                super.init( frame: frame )

                // - Hierarchy
                self.contentView.addSubview( self.iconView )

                // - Layout
                LayoutConfiguration( view: self.iconView )
                        .constrain( as: .center ).activate()
            }
        }
    }

    class LogoItem: PickerItem<AppConfig, AppIcon, LogoItem.Cell> {
        init() {
            super.init( track: .subject( "app", action: "theme" ),
                        title: "Application Logos",
                        values: { _ in AppIcon.allCases }, value: { _ in .current }, update: { $1.activate() },
                        caption: { _ in "Pick your favourite home screen icon for \(productName)." } )

            self.addBehaviour( ConditionalBehaviour( effect: .reveals ) { _ in
                UIApplication.shared.supportsAlternateIcons
            } )
        }

        override func populate(_ cell: Cell, indexPath: IndexPath, value: AppIcon) {
            cell.logo = value
        }

        class Cell: EffectCell {
            let logoView = UIImageView()
            var logo: AppIcon = AppIcon.primary {
                didSet {
                    DispatchQueue.main.perform {
                        self.logoView.image = self.logo.image
                    }
                }
            }

            required init?(coder aDecoder: NSCoder) {
                fatalError( "init(coder:) is not supported for this class" )
            }

            override init(frame: CGRect) {
                super.init( frame: frame )

                // - Hierarchy
                self.effectView.addContentView( self.logoView )

                // - Layout
                LayoutConfiguration( view: self.logoView )
                        .compressionResistance( horizontal: .defaultLow, vertical: .defaultLow )
                        .constrain( as: .box ).activate()
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
}
