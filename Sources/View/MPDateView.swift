//
// Created by Maarten Billemont on 2019-04-27.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPDateView: MPEffectView {
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
        self.monthFormatter.dateFormat = "MMM"
        self.dayFormatter.dateFormat = "dd"

        self.contentView.layoutMargins = UIEdgeInsets( top: 4, left: 4, bottom: 4, right: 4 )

        self.separatorView.backgroundColor = appConfig.theme.color.body.get()

        self.monthLabel.textColor = appConfig.theme.color.body.get()
        self.monthLabel.textAlignment = .center
        self.monthLabel.font = appConfig.theme.font.caption1.get()

        self.dayLabel.textColor = appConfig.theme.color.body.get()
        self.dayLabel.textAlignment = .center
        self.dayLabel.font = appConfig.theme.font.largeTitle.get()

        // - Hierarchy
        self.contentView.addSubview( self.separatorView )
        self.contentView.addSubview( self.monthLabel )
        self.contentView.addSubview( self.dayLabel )

        // - Layout
        self.widthAnchor.constraint( equalTo: self.heightAnchor, constant: 0.618 ).isActive = true
        LayoutConfiguration( view: self.monthLabel )
                .constrainTo { $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.topAnchor ) }
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( equalTo: self.separatorView.topAnchor ) }
                .activate()
        LayoutConfiguration( view: self.separatorView )
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                .constrainTo { $1.heightAnchor.constraint( equalToConstant: 1 ) }
                .activate()
        LayoutConfiguration( view: self.dayLabel )
                .constrainTo { $1.topAnchor.constraint( equalTo: self.separatorView.bottomAnchor ) }
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.layoutMarginsGuide.bottomAnchor ) }
                .activate()
    }
}
