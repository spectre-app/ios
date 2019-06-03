//
// Created by Maarten Billemont on 2019-04-27.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPDateView: UIView {
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
        super.init( frame: .zero )

        monthFormatter.dateFormat = "MMM"
        dayFormatter.dateFormat = "dd"

        self.backgroundColor = UIColor.white.withAlphaComponent( 0.12 )
        self.layoutMargins = UIEdgeInsets( top: 4, left: 4, bottom: 4, right: 4 )
        self.layer.cornerRadius = 8
        self.layer.borderWidth = 3
        self.layer.borderColor = UIColor.white.cgColor
        self.layer.masksToBounds = true

        self.separatorView.backgroundColor = .white

        self.monthLabel.textColor = .white
        self.monthLabel.textAlignment = .center
        self.monthLabel.font = UIFont.preferredFont( forTextStyle: .caption1 )

        self.dayLabel.textColor = .white
        self.dayLabel.textAlignment = .center
        if #available( iOS 11.0, * ) {
            self.dayLabel.font = UIFont.preferredFont( forTextStyle: .largeTitle )
        }
        else {
            self.dayLabel.font = UIFont.preferredFont( forTextStyle: .title1 ).withSymbolicTraits( .traitBold )
        }

        self.addSubview( self.separatorView )
        self.addSubview( self.monthLabel )
        self.addSubview( self.dayLabel )

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
        LayoutConfiguration( view: self )
                .constrainTo { $1.widthAnchor.constraint( equalTo: $1.heightAnchor, constant: 0.618 ) }
                .activate()
    }
}
