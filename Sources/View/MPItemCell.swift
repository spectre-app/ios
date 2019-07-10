//
// Created by Maarten Billemont on 2019-03-31.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

class MPItemCell: UICollectionViewCell {
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

        self.contentView.backgroundColor = MPTheme.global.color.glow.get()?.withAlphaComponent( 0.382 )
        self.contentView.layoutMargins = UIEdgeInsets( top: 4, left: 4, bottom: 4, right: 4 )
        self.contentView.layer.borderWidth = 2
        self.contentView.layer.borderColor = MPTheme.global.color.body.get()?.cgColor
        self.contentView.layer.shadowOpacity = 1
        self.contentView.layer.shadowRadius = 0
        self.contentView.layer.shadowOffset = CGSize( width: 0, height: 1 )
        self.contentView.layer.masksToBounds = true

        LayoutConfiguration( view: self.contentView )
                .constrainTo { $1.widthAnchor.constraint( equalTo: $1.heightAnchor ) }
                .constrainTo { $1.widthAnchor.constraint( equalToConstant: 70 ).withPriority( .defaultHigh ) }
                .constrainToOwner()
                .activate()

        defer {
            UIView.performWithoutAnimation {
                self.isSelected = false
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.contentView.layer.cornerRadius = self.contentView.bounds.size.height / 2
    }
}
