//
// Created by Maarten Billemont on 2019-03-31.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

class MPClassItemCell: MPItemCell {
    let separatorView = UIView()
    let nameLabel     = UILabel()
    let classLabel    = UILabel()

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override init(frame: CGRect) {
        super.init( frame: frame )

        self.separatorView.backgroundColor = MPTheme.global.color.body.get()
        self.nameLabel.textColor = MPTheme.global.color.body.get()
        self.nameLabel.textAlignment = .center
        self.nameLabel.font = MPTheme.global.font.headline.get()
        self.classLabel.textColor = MPTheme.global.color.body.get()
        self.classLabel.textAlignment = .center
        self.classLabel.font = MPTheme.global.font.caption1.get()

        self.effectView.contentView.addSubview( self.separatorView )
        self.effectView.contentView.addSubview( self.nameLabel )
        self.effectView.contentView.addSubview( self.classLabel )

        LayoutConfiguration( view: self.separatorView )
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                .constrainTo { $1.centerYAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerYAnchor ) }
                .constrainTo { $1.heightAnchor.constraint( equalToConstant: 1 ) }
                .activate()
        LayoutConfiguration( view: self.nameLabel )
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerYAnchor ) }
                .activate()
        LayoutConfiguration( view: self.classLabel )
                .constrainTo { $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerYAnchor ) }
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                .activate()
    }
}

class MPResultTypeCell: MPClassItemCell {
    public var resultType: MPResultType? {
        didSet {
            DispatchQueue.main.perform {
                if let resultType = self.resultType {
                    self.nameLabel.text = String( safeUTF8: mpw_type_abbreviation( resultType ) )

                    if 0 != resultType.rawValue & UInt32( MPResultTypeClass.template.rawValue ) {
                        self.classLabel.text = "Template"
                    }
                    else if 0 != resultType.rawValue & UInt32( MPResultTypeClass.stateful.rawValue ) {
                        self.classLabel.text = "Stateful"
                    }
                    else if 0 != resultType.rawValue & UInt32( MPResultTypeClass.derive.rawValue ) {
                        self.classLabel.text = "Derive"
                    }
                    else {
                        self.classLabel.text = ""
                    }
                }
                else {
                    self.nameLabel.text = ""
                    self.classLabel.text = ""
                }
            }
        }
    }
}
