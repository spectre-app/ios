//
// Created by Maarten Billemont on 2019-03-31.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPItemCell: UICollectionViewCell {

    // MARK: --- State ---

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
    let debugLabel = UILabel()

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override init(frame: CGRect) {
        super.init( frame: frame )

        self.effectView.layoutMargins = .border( 6 )

        self.contentView.addSubview( self.effectView )
        self.contentView.addSubview( self.debugLabel )

        LayoutConfiguration( view: self.contentView )
                .constrain { $1.widthAnchor.constraint( equalTo: $1.heightAnchor ) }
                .constrain { $1.widthAnchor.constraint( equalToConstant: 70 ).with( priority: .defaultHigh ) }.constrain( as: .box )
                .activate()
        LayoutConfiguration( view: self.debugLabel ).constrain( as: .bottomBox )
                                                    .activate()
        LayoutConfiguration( view: self.effectView ).constrain( as: .box )
                                                    .activate()

        defer {
            self.isSelected = false
        }
    }
}
