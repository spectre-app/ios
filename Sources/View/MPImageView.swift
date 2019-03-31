//
// Created by Maarten Billemont on 2018-09-24.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPImageView: UIImageView {
    var ratioPreservingConstraint: NSLayoutConstraint?
    var preservesImageRatio = false {
        didSet {
            self.needsUpdateConstraints()
        }
    }
    override var image: UIImage? {
        didSet {
            self.needsUpdateConstraints()
        }
    }

    override func updateConstraints() {
        super.updateConstraints()

        if let image = self.image {
            let ratio = image.size.width / image.size.height
            if self.ratioPreservingConstraint?.multiplier != ratio {
                self.ratioPreservingConstraint?.isActive = false
                self.ratioPreservingConstraint = self.widthAnchor.constraint( equalTo: self.heightAnchor, multiplier: ratio )
                self.ratioPreservingConstraint?.isActive = true
            }
        }
        else {
            self.ratioPreservingConstraint?.isActive = false
            self.ratioPreservingConstraint = nil
        }
    }
}
