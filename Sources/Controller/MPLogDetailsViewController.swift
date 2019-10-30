//
// Created by Maarten Billemont on 2019-07-05.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPLogDetailsViewController: MPDetailsViewController<MPLogDetailsViewController.Model> {

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init() {
        super.init( model: Model() )

        self.model.onChange = {
            self.setNeedsUpdate()
        }
    }

    override func loadItems() -> [Item<Model>] {
        [ VersionItem(), SeparatorItem(),
          LogLevelPicker(), LogsItem() ]
    }

    // MARK: --- Types ---

    class VersionItem: LabelItem<Model> {
        init() {
            super.init( title: "\(PearlInfoPlist.get().cfBundleDisplayName ?? productName)",
                        value: { _ in PearlInfoPlist.get().cfBundleShortVersionString },
                        caption: { _ in PearlInfoPlist.get().cfBundleVersion } )
        }
    }

    class LogsItem: AreaItem<Model> {
        init() {
            super.init( value: {
                PearlLogger.get().messages( with: $0.logbookLevel ).reduce( "" ) {
                    "\($0 ?? "")\($1.occurrenceDescription()) [\($1.level.short)] \($1.sourceDescription())\n\($1.message)\n\n"
                }
            } )
        }

        override func doUpdate() {
            super.doUpdate()

            if let view = (self.view as? AreaItemView<Model>)?.valueView {
                view.scrollRectToVisible( CGRect( x: 0, y: view.contentSize.height, width: 0, height: 0 ), animated: true )
            }
        }
    }

    class LogLevelPicker: PickerItem<Model, PearlLogLevel> {
        init() {
            super.init(
                    title: "Logbook",
                    values: { _ in PearlLogLevel.allCases },
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
            collectionView.registerCell( Cell.self )
        }

        override func cell(collectionView: UICollectionView, indexPath: IndexPath, model: Model, value: PearlLogLevel) -> UICollectionViewCell? {
            Cell.dequeue( from: collectionView, indexPath: indexPath ) { cell in
                (cell as? Cell)?.level = value
            }
        }

        class Cell: MPItemCell {
            var level = PearlLogLevel.trace {
                didSet {
                    DispatchQueue.main.perform {
                        self.titleLabel.text = self.level.description
                    }
                }
            }

            private let titleLabel = UILabel()

            required init?(coder aDecoder: NSCoder) {
                fatalError( "init(coder:) is not supported for this class" )
            }

            override init(frame: CGRect) {
                super.init( frame: frame )

                self.titleLabel.font = MPTheme.global.font.headline.get()
                self.titleLabel.textColor = MPTheme.global.color.body.get()
                self.titleLabel.textAlignment = .center

                self.effectView.contentView.addSubview( self.titleLabel )

                LayoutConfiguration( view: self.titleLabel )
                        .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                        .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                        .constrainTo { $1.centerYAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerYAnchor ) }
                        .activate()
            }
        }
    }

    class Model {
        var onChange: (() -> ())?

        var logbookLevel = PearlLogger.get().historyLevel {
            didSet {
                PearlLogger.get().minimumLevel = min( PearlLogLevel.info, self.logbookLevel )
                PearlLogger.get().historyLevel = min( PearlLogLevel.info, self.logbookLevel )
                self.onChange?()
            }
        }
    }
}
