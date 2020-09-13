//
// Created by Maarten Billemont on 2019-03-31.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPItemCell: UICollectionViewCell {
    override var isSelected: Bool {
        didSet {
            DispatchQueue.main.perform {
                UIView.animate( withDuration: .short ) {
                    self.effectView.isSelected = self.isSelected
                }
            }

            if self.isSelected != oldValue, self.isSelected, UIView.areAnimationsEnabled {
                MPFeedback.shared.play( .trigger )
            }
        }
    }

    let effectView = MPEffectView( round: true, dims: true )

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override init(frame: CGRect) {
        super.init( frame: frame )

        self.effectView.layoutMargins = UIEdgeInsets( top: 6, left: 6, bottom: 6, right: 6 )

        self.contentView.addSubview( self.effectView )

        LayoutConfiguration( view: self.contentView )
                .constrainTo { $1.widthAnchor.constraint( equalTo: $1.heightAnchor ) }
                .constrainTo { $1.widthAnchor.constraint( equalToConstant: 70 ).with( priority: .defaultHigh ) }
                .constrain()
                .activate()
        LayoutConfiguration( view: self.effectView )
                .constrain()
                .activate()

        defer {
            self.isSelected = false
        }
    }
}
