//
// Created by Maarten Billemont on 2019-07-05.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit
import Countly

class MPLogDetailsViewController: MPItemsViewController<MPLogDetailsViewController.Model>, ModelObserver {

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(focus: Item<Model>.Type? = nil) {
        super.init( model: Model(), focus: focus )

        self.model.observers.register( observer: self )
    }

    override func loadItems() -> [Item<Model>] {
        [ FeedbackItem(), CrashItem(), SeparatorItem(),
          LogLevelPicker(), LogsItem(), SeparatorItem(),
          DeviceIdentifierItem(), OwnerIdentifierItem(),
        ]
    }

    // MARK: --- ModelObserver ---

    func didChange() {
        self.setNeedsUpdate()
    }

    // MARK: --- Types ---

    class FeedbackItem: ButtonItem<Model> {
        init() {
            super.init( track: .subject( "logbook", action: "feedback" ),
                        value: { _ in (label: "Let's Talk 🅿︎", image: nil) },
                        caption: { _ in
                            """
                            We're here to help.  You can also reach us at:\nsupport@volto.app
                            """
                        } ) {
                if let viewController = $0.viewController {
                    let options = ConversationOptions()
                    options.filter( byTags: [ "premium" ], withTitle: "Premium Support" )
                    Freshchat.sharedInstance().showConversations( viewController, with: options )
                }
            }

            self.addBehaviour( PremiumTapBehaviour() )
            self.addBehaviour( PremiumConditionalBehaviour( mode: .enables ) )
        }
    }

    class CrashItem: ButtonItem<Model> {
        init() {
            super.init( track: .subject( "logbook", action: "crash" ),
                        value: { _ in (label: "Force Crash 🅳", image: nil) },
                        caption: { _ in
                            """
                            Terminate the app with a crash, triggering a crash report on the next launch.
                            """
                        } ) { _ in
                fatalError( "Forced Crash" )
            }

            self.addBehaviour( RequiresDebug( mode: .reveals ) )
        }
    }

    class LogLevelPicker: PickerItem<Model, MPLogLevel, LogLevelPicker.Cell> {
        init() {
            super.init( track: .subject( "logbook", action: "level" ), title: "Logbook",
                        values: { _ in MPLogLevel.allCases.reversed() },
                        value: { $0.logbookLevel }, update: { $0.logbookLevel = $1 },
                        caption: { _ in
                            """
                            Show only messages at the selected level or higher.
                            Debug and trace messages are not recorded unless the level is set accordingly.
                            """
                        } )
        }

        override func populate(_ cell: Cell, indexPath: IndexPath, value: MPLogLevel) {
            cell.level = value
        }

        class Cell: MPItemCell {
            var level = MPLogLevel.trace {
                didSet {
                    DispatchQueue.main.perform {
                        self.titleLabel.text = self.level.description
                    }
                }
            }

            private let titleLabel = UILabel()

            // MARK: --- Life ---

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
                MPLogSink.shared.enumerate( level: $0.logbookLevel ).reduce( NSMutableAttributedString() ) { logs, record in
                    logs.append( NSAttributedString(
                            string: "\(dateFormatter.string( from: record.occurrence )) \(record.level) | \(record.source)\n",
                            attributes: [
                                .font: Theme.current.font.mono.get( size: 11 ) as Any,
                                .foregroundColor: Theme.current.color.secondary.get() as Any,
                            ] ) )
                    logs.append( NSAttributedString(
                            string: "\(record.message)\n",
                            attributes: [
                                .font: Theme.current.font.mono.get( size: 11, traits: record.level <= .warning ? .traitBold: [] ) as Any,
                                .foregroundColor: Theme.current.color.body.get() as Any,
                            ] ) )
                    return logs
                }
            }, subitems: [
                ButtonItem( track: .subject( "logbook", action: "copy" ), value: { _ in (label: "Copy Logs", image: nil) }, action: {
                    UIPasteboard.general.setItems( [ [ UIPasteboard.typeAutomatic:
                    MPLogSink.shared.enumerate( level: $0.model?.logbookLevel ?? .info ).reduce( "" ) { logs, record in
                        logs + "[\(dateFormatter.string( from: record.occurrence )) \(record.level) | \(record.source)] " +
                                record.message + "\n"
                    } ] ] )
                } )
            ] )
        }
    }

    class DeviceIdentifierItem: Item<Model> {
        init() {
            super.init( title: "Device Identifier",
                        caption: { _ in MPTracker.shared.identifierForDevice } )

            self.addBehaviour( BlockTapBehaviour() { _ in
                UIPasteboard.general.setItems(
                        [ [ UIPasteboard.typeAutomatic: MPTracker.shared.identifierForDevice ] ] )
            } )
        }
    }

    class OwnerIdentifierItem: Item<Model> {
        init() {
            super.init( title: "Owner Identifier",
                        caption: { _ in MPTracker.shared.identifierForOwner } )

            self.addBehaviour( BlockTapBehaviour() { _ in
                UIPasteboard.general.setItems(
                        [ [ UIPasteboard.typeAutomatic: MPTracker.shared.identifierForOwner ] ] )
            } )
        }
    }

    class Model: Observable {
        let observers = Observers<ModelObserver>()

        var logbookLevel = MPLogSink.shared.level {
            didSet {
                MPLogSink.shared.level = max( .info, self.logbookLevel )

                self.observers.notify { $0.didChange() }
            }
        }
    }
}

protocol ModelObserver {
    func didChange()
}
