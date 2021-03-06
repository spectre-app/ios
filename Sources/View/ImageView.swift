// =============================================================================
// Created by Maarten Billemont on 2018-09-24.
// Copyright (c) 2018 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import UIKit

class ImageView: UIImageView {
    public var preservesImageRatio = false {
        didSet {
            self.needsUpdateConstraints()
        }
    }

    private var  ratioPreservingConstraint: NSLayoutConstraint?
    override var image:                     UIImage? {
        didSet {
            self.needsUpdateConstraints()
        }
    }

    override func updateConstraints() {
        super.updateConstraints()

        if self.preservesImageRatio, let image = self.image {
            let ratio = image.size.width / image.size.height
            if self.ratioPreservingConstraint?.multiplier != ratio {
                self.ratioPreservingConstraint?.isActive = false
                self.ratioPreservingConstraint = self.widthAnchor.constraint( equalTo: self.heightAnchor, multiplier: ratio )
                self.ratioPreservingConstraint?.priority = .defaultHigh + 10
                self.ratioPreservingConstraint?.isActive = true
            }
        }
        else {
            self.ratioPreservingConstraint?.isActive = false
            self.ratioPreservingConstraint = nil
        }
    }
}
