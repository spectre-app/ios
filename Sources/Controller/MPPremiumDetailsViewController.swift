//
// Created by Maarten Billemont on 2019-07-05.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPPremiumDetailsViewController: MPDetailsViewController<Void> {

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init() {
        super.init( model: () )
    }

    override func loadItems() -> [Item<Void>] {
        [ HeaderItem(), SeparatorItem(),
          Item<Void>( subitems: [
              FeatureItem( title: "Biometric Lock", value: { _ in UIImage.icon( "", withSize: 48 ) },
                           caption: { _ in "A touch or smile can open doors.  Get in even faster." } ),
              FeatureItem( title: "Password Auto-Fill", value: { _ in UIImage.icon( "", withSize: 48 ) },
                           caption: { _ in "Your passwords exactly when you need them, instantly, from any app." } ),
          ] ),
          Item<Void>( subitems: [
              FeatureItem( title: "Application Themes", value: { _ in UIImage.icon( "", withSize: 48 ) },
                           caption: { _ in "Make it yours and dye Spectre with a dash of personality." } ),
              FeatureItem( title: "Password Strength", value: { _ in UIImage.icon( "", withSize: 48 ) },
                           caption: { _ in "Understand what a password's complexity truly translates into." } ),
          ] ),
          Item<Void>( subitems: [
              FeatureItem( title: "Login Name Generator", value: { _ in UIImage.icon( "", withSize: 48 ) },
                           caption: { _ in "Upgrade your cross-site anonymity with unique site login names." } ),
              FeatureItem( title: "Security Answer Generator", value: { _ in UIImage.icon( "", withSize: 48 ) },
                           caption: { _ in "Say No to those pretentiously invasive \"security\" questions." } ),
          ] ), ]
    }

    // MARK: --- Types ---

    class HeaderItem: ImageItem<Void> {
        init() {
            super.init( title: "\(productName)",
                        value: { _ in UIImage.icon( "", withSize: 64 ) },
                        caption: { _ in "Premium" } )
        }
    }

    class FeatureItem: ImageItem<Void> {
    }
}
