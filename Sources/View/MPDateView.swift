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

    override init() {
        super.init()

        // - View
        self.monthFormatter.dateFormat = "MMM"
        self.dayFormatter.dateFormat = "dd"

        //self.backgroundColor = MPTheme.global.color.mute.get()
        self.layoutMargins = UIEdgeInsets( top: 4, left: 4, bottom: 4, right: 4 )
        self.layer.cornerRadius = 8
        self.layer.borderWidth = 2
        self.layer.borderColor = MPTheme.global.color.body.get()?.cgColor
        self.layer.shadowRadius = 0
        self.layer.shadowOpacity = 1
        self.layer.shadowColor = MPTheme.global.color.shadow.get()?.cgColor
        self.layer.shadowOffset = CGSize( width: 0, height: 1 )
        self.layer.masksToBounds = true

        self.separatorView.backgroundColor = MPTheme.global.color.body.get()

        self.monthLabel.textColor = MPTheme.global.color.body.get()
        self.monthLabel.textAlignment = .center
        self.monthLabel.font = MPTheme.global.font.caption1.get()

        self.dayLabel.textColor = MPTheme.global.color.body.get()
        self.dayLabel.textAlignment = .center
        self.dayLabel.font = MPTheme.global.font.largeTitle.get()

        // - Hierarchy
        self.contentView.addSubview( self.separatorView )
        self.contentView.addSubview( self.monthLabel )
        self.contentView.addSubview( self.dayLabel )

        // - Layout
        self.widthAnchor.constraint( equalTo: self.heightAnchor, constant: 0.618 ).activate()
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
