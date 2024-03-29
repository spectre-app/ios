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

class DetailLogViewController: ItemsViewController<DetailLogViewController.Model>, AppConfigObserver, ModelObserver {

    // MARK: - Life

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(focus: Item<Model>.Type? = nil) {
        super.init( model: Model(), focus: focus )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear( animated )

        AppConfig.shared.observers.register( observer: self )
        self.model.observers.register( observer: self )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear( animated )

        AppConfig.shared.observers.unregister( observer: self )
        self.model.observers.unregister( observer: self )
    }

    override func loadItems() -> [Item<Model>] {
        [ CrashItem(), MemoryProfilerItem(), SeparatorItem(),
          LogLevelPicker(), LogsItem(), SeparatorItem(),
          DeviceIdentifierItem(), OwnerIdentifierItem(),
        ]
    }

    // MARK: - AppConfigObserver

    func didChange(appConfig: AppConfig, at change: PartialKeyPath<AppConfig>) {
        self.setNeedsUpdate()
    }

    // MARK: - ModelObserver

    func didChange(model: Model) {
        self.setNeedsUpdate()
    }

    // MARK: - Types

//    class FeedbackItem: ButtonItem<Model> {
//        init() {
//            super.init( track: .subject( "logbook", action: "feedback" ),
//                        value: { _ in (label: "Let's Talk 🅿︎", image: nil) },
//                        caption: { _ in
//                            """
//                            We're here to help.  You can also reach us at:\nsupport@spectre.app
//                            """
//                        },
//                        action: {
//                            if let viewController = $0.viewController {
//                                let options = ConversationOptions()
//                                options.filter( byTags: [ "premium" ], withTitle: "Premium Support" )
//                                Freshchat.sharedInstance().showConversations( viewController, with: options )
//                            }
//                        } )
//
//            if Freshchat.sharedInstance().config.appKey.nonEmpty == nil,
//               let freshchatApp = secrets.freshchat.app.b64Decrypt(), let freshchatKey = secrets.freshchat.key.b64Decrypt() {
//                let freshchatConfig = FreshchatConfig( appID: freshchatApp, andAppKey: freshchatKey )
//                freshchatConfig.domain = "msdk.eu.freshchat.com"
//                Freshchat.sharedInstance().initWith( freshchatConfig )
//            }
//
//            self.addBehaviour( ConditionalBehaviour( effect: .hides ) { _ in Freshchat.sharedInstance().config.appKey.nonEmpty == nil } )
//            self.addBehaviour( FeatureTapBehaviour( feature: .premium ) )
//            self.addBehaviour( FeatureConditionalBehaviour( feature: .premium, effect: .enables ) )
//            self.addBehaviour( ConditionalBehaviour( effect: .enables ) { _ in !AppConfig.shared.offline } )
//        }
//    }

    class CrashItem: ButtonItem<Model> {
        init() {
            super.init( track: .subject( "logbook", action: "crash" ),
                        value: { _ in (label: "Force Crash 🅳", image: nil) },
                        caption: { _ in
                            """
                            Terminate the app with a crash, triggering a crash report on the next launch.
                            """
                        },
                        action: { _ in
                            Tracker.shared.crash()
                        } )

            self.addBehaviour( IfDebug( effect: .reveals ) )
        }
    }

    class MemoryProfilerItem: ToggleItem<Model> {
        init() {
            super.init( track: .subject( "logbook", action: "memoryProfiler" ),
                        title: "Memory Profiler", icon: { _ in .icon( "nfc-magnifying-glass" ) },
                        value: { _ in AppConfig.shared.memoryProfiler }, update: { AppConfig.shared.memoryProfiler = $1 },
                        subitems: [
                            ButtonItem( track: .subject( "logbook", action: "leaks" ),
                                        value: { _ in (label: "Report Leaks", image: nil) },
                                        caption: { _ in
                                            """
                                            Shut down the application and report on remaining leaked objects.
                                            """
                                        } ) { _ in AppDelegate.shared?.reportLeaks() }
                                .addBehaviour( ConditionalBehaviour( effect: .enables ) { _ in AppConfig.shared.memoryProfiler } )
                        ] )
        }
    }

    class LogLevelPicker: PickerItem<Model, SpectreLogLevel, LogLevelPicker.Cell> {
        init() {
            super.init( track: .subject( "logbook", action: "level" ), title: "Logbook",
                        values: { _ in SpectreLogLevel.allCases.reversed() },
                        value: { $0.logbookLevel }, update: { $0.model?.logbookLevel = $1 },
                        caption: { _ in
                            """
                            Show only messages at the selected level or higher.
                            Debug and trace messages are not recorded unless the level is set accordingly.
                            """
                        } )
        }

        override func populate(_ cell: Cell, indexPath: IndexPath, value: SpectreLogLevel) {
            cell.level = value
        }

        class Cell: EffectCell {
            var level = SpectreLogLevel.trace {
                didSet {
                    DispatchQueue.main.perform {
                        self.titleLabel.text = self.level.description
                    }
                }
            }

            private let titleLabel = UILabel()

            // MARK: - Life

            required init?(coder aDecoder: NSCoder) {
                fatalError( "init(coder:) is not supported for this class" )
            }

            override init(frame: CGRect) {
                super.init( frame: frame )

                // - View
                self.titleLabel => \.font => Theme.current.font.headline
                self.titleLabel => \.textColor => Theme.current.color.body
                self.titleLabel.textAlignment = .center

                // - Hierarchy
                self.effectView.addContentView( self.titleLabel )

                // - Layout
                LayoutConfiguration( view: self.titleLabel )
                    .constrain { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                    .constrain { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                    .constrain { $1.centerYAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerYAnchor ) }
                    .activate()
            }
        }
    }

    class LogsItem: AreaItem<Model, NSAttributedString> {
        init() {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "DDD'-'HH':'mm':'ss"

            super.init( value: {
                let font = Theme.current.font.mono.get(forTraits: .current)?.withSize( 11 )
                let boldFont = font?.withSymbolicTraits( .traitBold )
                return LogSink.shared.enumerate( level: $0.logbookLevel ).reduce( NSMutableAttributedString() ) { logs, record in
                    logs.append( NSAttributedString(
                            string: "\(dateFormatter.string( from: record.occurrence )) \(record.level) | \(record.source)\n",
                            attributes: [
                                .font: font as Any,
                                .foregroundColor: Theme.current.color.secondary.get(forTraits: .current) as Any,
                            ] ) )
                    logs.append( NSAttributedString(
                            string: "\(record.message)\n",
                            attributes: [
                                .font: (record.level <= .warning ? boldFont : font) as Any,
                                .foregroundColor: Theme.current.color.body.get(forTraits: .current) as Any,
                            ] ) )
                    return logs
                }
            }, subitems: [
                ButtonItem( track: .subject( "logbook", action: "copy" ), value: { _ in (label: "Copy Logs", image: nil) }, action: {
                    let logs = LogSink.shared.enumerate( level: $0.model?.logbookLevel ?? .info ).reduce( "" ) { logs, log in
                        "\(logs)[\(dateFormatter.string( from: log.occurrence )) \(log.level) | \(log.source)] \(log.message)\n"
                    }

                    inf( "Copying logs." )
                    UIPasteboard.general.setObjects(
                            [ logs as NSString ], localOnly: !AppConfig.shared.allowHandoff, expirationDate: nil )
                } ),
            ] )
        }
    }

    class DeviceIdentifierItem: Item<Model> {
        init() {
            super.init( title: "Device Identifier",
                        caption: { _ in "\(Tracker.shared.identifierForDevice)" } )

            self.addBehaviour( BlockTapBehaviour { _ in
                inf( "Copying device identifier: %@", Tracker.shared.identifierForDevice )
                UIPasteboard.general.setObjects(
                        [ Tracker.shared.identifierForDevice as NSString ], localOnly: !AppConfig.shared.allowHandoff, expirationDate: nil )
            } )
        }
    }

    class OwnerIdentifierItem: Item<Model> {
        init() {
            super.init( title: "Owner Identifier",
                        caption: { _ in "\(Tracker.shared.identifierForOwner)" } )

            self.addBehaviour( BlockTapBehaviour { _ in
                inf( "Copying owner identifier: %@", Tracker.shared.identifierForOwner )
                UIPasteboard.general.setObjects(
                        [ Tracker.shared.identifierForOwner as NSString ], localOnly: !AppConfig.shared.allowHandoff, expirationDate: nil )
            } )
        }
    }

    class Model: Observable {
        let observers = Observers<ModelObserver>()

        var logbookLevel = LogSink.shared.level {
            didSet {
                LogSink.shared.level = max( .info, self.logbookLevel )

                self.observers.notify { $0.didChange( model: self ) }
            }
        }
    }
}

protocol ModelObserver {
    func didChange(model: DetailLogViewController.Model)
}
