// =============================================================================
// Created by Maarten Billemont on 2019-03-31.
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

class EffectCell: UICollectionViewCell {

    // MARK: - State

    override var isSelected: Bool {
        didSet {
            DispatchQueue.main.perform {
                UIView.animate( withDuration: .short ) {
                    self.effectView.isSelected = self.isSelected
                }
            }

            if self.isSelected != oldValue, self.isSelected, UIView.areAnimationsEnabled {
                Feedback.shared.play( .trigger )
            }
        }
    }

    let effectView = EffectView( circular: false, dims: true )
    let debugLabel = UILabel()

    // MARK: - Life

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override init(frame: CGRect) {
        super.init( frame: frame )
        LeakRegistry.shared.register( self )

        self.effectView.layoutMargins = .border( 6 )

        self.contentView.addSubview( self.effectView )
        self.contentView.addSubview( self.debugLabel )

        LayoutConfiguration( view: self.contentView )
            .constrain { $1.widthAnchor.constraint( equalTo: $1.heightAnchor ) }
            .constrain { $1.widthAnchor.constraint( equalToConstant: 88 ).with( priority: .defaultHigh - 1 ) }.constrain( as: .box )
            .activate()
        LayoutConfiguration( view: self.debugLabel )
            .constrain( as: .bottomBox ).activate()
        LayoutConfiguration( view: self.effectView )
            .constrain( as: .box ).activate()

        defer {
            self.isSelected = false
        }
    }
}
