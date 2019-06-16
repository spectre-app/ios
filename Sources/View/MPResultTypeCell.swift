//
// Created by Maarten Billemont on 2019-03-31.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

class MPResultTypeCell: UICollectionViewCell {
    public var resultType: MPResultType? {
        didSet {
            DispatchQueue.main.perform {
                if let resultType = self.resultType {
                    self.nameLabel.text = String( safeUTF8: mpw_abbreviationForType( resultType ) )

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

    private let separatorView = UIView()
    private let nameLabel     = UILabel()
    private let classLabel    = UILabel()
    override var isSelected: Bool {
        didSet {
            DispatchQueue.main.perform {
                UIView.animate( withDuration: 0.382 ) {
                    self.contentView.alpha = self.isSelected ? 1: 0.618
                }
            }
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override init(frame: CGRect) {
        super.init( frame: frame )

        self.separatorView.backgroundColor = MPTheme.global.color.glow.get()
        self.nameLabel.textColor = MPTheme.global.color.glow.get()
        self.nameLabel.textAlignment = .center
        self.nameLabel.font = MPTheme.global.font.headline.get()
        self.classLabel.textColor = MPTheme.global.color.glow.get()
        self.classLabel.textAlignment = .center
        self.classLabel.font = MPTheme.global.font.caption1.get()

        self.contentView.backgroundColor = MPTheme.global.color.glow.get()?.withAlphaComponent( 0.382 )
        self.contentView.layoutMargins = UIEdgeInsets( top: 4, left: 4, bottom: 4, right: 4 )
        self.contentView.layer.borderWidth = 2
        self.contentView.layer.borderColor = MPTheme.global.color.glow.get()?.cgColor
        self.contentView.layer.masksToBounds = true
        self.contentView.addSubview( self.separatorView )
        self.contentView.addSubview( self.nameLabel )
        self.contentView.addSubview( self.classLabel )

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
        LayoutConfiguration( view: self.contentView )
                .constrainTo { $1.widthAnchor.constraint( equalTo: $1.heightAnchor ) }
                .constrainTo { $1.widthAnchor.constraint( equalToConstant: 70 ).withPriority( .defaultHigh ) }
                .constrainToOwner()
                .activate()

        defer {
            self.isSelected = false
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.contentView.layer.cornerRadius = self.contentView.bounds.size.height / 2
    }
}
