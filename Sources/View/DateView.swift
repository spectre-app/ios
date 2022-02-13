// =============================================================================
// Created by Maarten Billemont on 2019-04-27.
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

class DateView: EffectView {
    public var date: Date? {
        didSet {
            DispatchQueue.main.perform {
                if let date = self.date {
                    self.monthLabel.text = self.monthFormatter.string( from: date )
                    self.dayLabel.text = self.dayFormatter.string( from: date )
                }
                else {
                    self.monthLabel.text = ""
                    self.dayLabel.text = ""
                }
            }
        }
    }

    private let monthFormatter = DateFormatter()
    private let dayFormatter   = DateFormatter()
    private let separatorView  = UIView()
    private let monthLabel     = UILabel()
    private let dayLabel       = UILabel()

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init() {
        super.init( rounding: 8 )

        // - View
        self.monthFormatter.setLocalizedDateFormatFromTemplate( "MMM" )
        self.dayFormatter.setLocalizedDateFormatFromTemplate( "dd" )

        self.layoutMargins = .border( 4 )

        self.separatorView => \.backgroundColor => Theme.current.color.mute

        self.monthLabel.textAlignment = .center
        self.monthLabel => \.textColor => Theme.current.color.body
        self.monthLabel => \.font => Theme.current.font.caption1

        self.dayLabel.textAlignment = .center
        self.dayLabel => \.textColor => Theme.current.color.body
        self.dayLabel => \.font => Theme.current.font.largeTitle

        // - Hierarchy
        self.addContentView( self.separatorView )
        self.addContentView( self.monthLabel )
        self.addContentView( self.dayLabel )

        // - Layout
        self.widthAnchor.constraint( equalTo: self.heightAnchor, constant: .long ).isActive = true
        LayoutConfiguration( view: self.monthLabel )
            .constrain { $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.topAnchor ) }
            .constrain { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
            .constrain { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
            .constrain { $1.bottomAnchor.constraint( equalTo: self.separatorView.topAnchor ) }
            .activate()
        LayoutConfiguration( view: self.separatorView )
            .constrain { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
            .constrain { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
            .constrain { $1.heightAnchor.constraint( equalToConstant: 1 ) }
            .activate()
        LayoutConfiguration( view: self.dayLabel )
            .constrain { $1.topAnchor.constraint( equalTo: self.separatorView.bottomAnchor ) }
            .constrain { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
            .constrain { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
            .constrain { $1.bottomAnchor.constraint( equalTo: $0.layoutMarginsGuide.bottomAnchor ) }
            .activate()
    }
}
