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
        return [ VersionItem(), SeparatorItem(),
                 LegacyItem(), SeparatorItem(),
                 InfoItem() ]
    }

    // MARK: --- Types ---

    class VersionItem: LabelItem<Void> {
        init() {
            super.init( title: "\(PearlInfoPlist.get().cfBundleDisplayName ?? "mPass")" ) { _ in
                (PearlInfoPlist.get().cfBundleShortVersionString, PearlInfoPlist.get().cfBundleVersion)
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
        }
    }

    class InfoItem: Item<Void> {
        init() {
            super.init( title: nil )
        }
    }
}
