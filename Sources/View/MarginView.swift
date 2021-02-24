//
// Created by Maarten Billemont on 2019-10-11.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MarginView: UIView {
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

    init(for view: UIView, margins: UIEdgeInsets? = nil) {
        super.init( frame: .zero )

        if let margins = margins {
            self.layoutMargins = margins
        }

        self.addSubview( view )
        LayoutConfiguration( view: view )
                .constrain( as: .box, margin: true ).activate()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override var forLastBaselineLayout: UIView {
        self.subviews.first ?? self
    }
}
