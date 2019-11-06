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
                    self.effectView.isSelected = self.isSelected
                }
            }

            if self.isSelected != oldValue, self.isSelected, UIView.areAnimationsEnabled {
                MPFeedback.shared.play( .trigger )
            }
        }
    }

    let effectView = MPEffectView()

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override init(frame: CGRect) {
        super.init( frame: frame )

        self.effectView.isRound = true
        self.effectView.isDimmedBySelection = true
        self.effectView.contentView.layoutMargins = UIEdgeInsets( top: 4, left: 4, bottom: 4, right: 4 )

        self.contentView.addSubview( self.effectView )

        LayoutConfiguration( view: self.contentView )
                .constrainTo { $1.widthAnchor.constraint( equalTo: $1.heightAnchor ) }
                .constrainTo { $1.widthAnchor.constraint( equalToConstant: 70 ).withPriority( .defaultHigh ) }
                .constrainToOwner()
                .activate()
        LayoutConfiguration( view: self.effectView )
                .constrainToOwner()
                .activate()

        defer {
            self.isSelected = false
        }
    }
}
