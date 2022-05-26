// =============================================================================
// Created by Maarten Billemont on 2019-10-11.
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

class MarginView: BaseView {
    override var isHidden: Bool {
        get {
            self.subviews.first?.isHidden ?? super.isHidden
        }
        set {
            if let view = self.subviews.first {
                view.isHidden = newValue
            }
            else {
                super.isHidden = newValue
            }
        }
    }

    convenience init(space: CGSize = CGSize( width: 8, height: 8 )) {
        let spacer = UIView()
        LayoutConfiguration( view: spacer )
            .constrain { $1.widthAnchor.constraint( equalToConstant: space.width ) }
            .constrain { $1.heightAnchor.constraint( equalToConstant: space.height ) }
            .activate()

        self.init( for: spacer, margins: .zero )
    }

    init(for view: UIView, margins: UIEdgeInsets? = nil, anchor: Anchor = .box) {
        super.init( frame: .zero )

        if let margins = margins {
            self.layoutMargins = margins
        }

        self.addSubview( view )
        LayoutConfiguration( view: view )
            .constrain( as: anchor, margin: true ).activate()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override var forLastBaselineLayout: UIView {
        self.subviews.first ?? self
    }
}
