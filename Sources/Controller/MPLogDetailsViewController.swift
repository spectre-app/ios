//
// Created by Maarten Billemont on 2019-07-05.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit
import Countly

class MPLogDetailsViewController: MPDetailsViewController<MPLogDetailsViewController.Model>, ModelObserver {

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init() {
        super.init( model: Model() )

        self.model.observers.register( observer: self )
    }

    override func loadItems() -> [Item<Model>] {
        [ FeedbackItem(), CrashItem(), SeparatorItem(),
          LogLevelPicker(), LogsItem(), SeparatorItem() ]
    }

    // MARK: --- ModelObserver ---

    func didChange() {
        self.setNeedsUpdate()
    }

    // MARK: --- Types ---

    class FeedbackItem: ButtonItem<Model> {
        init() {
            super.init( identifier: "logbook #feedback",
                        value: { _ in (label: "Let's Talk 🅿", image: nil) },
                        caption: { _ in "We're here to help.  You can also reach us at:\nsupport@volto.app" } ) {
                let options = ConversationOptions()
                options.filter( byTags: [ "premium" ], withTitle: "Premium Support" )
                Freshchat.sharedInstance().showConversations( $0.viewController, with: options )
            }
        }
    }

    class CrashItem: ButtonItem<Model> {
        init() {
            super.init( identifier: "logbook #crash",
                        value: { _ in (label: "Force Crash", image: nil) },
                        caption: { _ in "Terminate the app with a crash, triggering a crash report on the next launch." },
                        hidden: { _ in !appConfig.isDebug }) { _ in
                fatalError( "Forced Crash" )
            }
        }
    }

    class LogLevelPicker: PickerItem<Model, LogLevel> {
        init() {
            super.init(
                    identifier: "logbook >level",
                    title: "Logbook",
                    values: { _ in LogLevel.allCases.reversed() },
                    value: { $0.logbookLevel },
                    update: { $0.logbookLevel = $1 },
                    caption: { _ in
                        """
                        Show only messages at the selected level or higher.
                        Debug and trace messages are not recorded unless the level is set accordingly.
                        """
                    } )
        }

        override func didLoad(collectionView: UICollectionView) {
            collectionView.register( Cell.self )
        }

        override func cell(collectionView: UICollectionView, indexPath: IndexPath, model: Model, value: LogLevel) -> UICollectionViewCell? {
            Cell.dequeue( from: collectionView, indexPath: indexPath ) { cell in
                (cell as? Cell)?.level = value
            }
        }

        class Cell: MPItemCell {
            var level = LogLevel.trace {
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
                self.titleLabel.font = appConfig.theme.font.headline.get()
                self.titleLabel.textColor = appConfig.theme.color.body.get()
                self.titleLabel.textAlignment = .center

                // - Hierarchy
                self.effectView.contentView.addSubview( self.titleLabel )

                // - Layout
                LayoutConfiguration( view: self.titleLabel )
                        .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                        .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                        .constrainTo { $1.centerYAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerYAnchor ) }
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
                                .font: appConfig.theme.font.mono.get()?.withSize( 11 ) as Any,
                                .foregroundColor: appConfig.theme.color.secondary.get() as Any,
                            ] ) )
                    logs.append( NSAttributedString(
                            string: "\(record.message)\n",
                            attributes: [
                                .font: appConfig.theme.font.mono.get()?.withSize( 11 ).withSymbolicTraits(
                                        record.level <= .warning ?
                                                .traitBold:
                                                [] ) as Any,
                                .foregroundColor: appConfig.theme.color.body.get() as Any,
                            ] ) )
                    return logs
                }
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
