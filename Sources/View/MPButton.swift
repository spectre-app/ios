//
// Created by Maarten Billemont on 2018-09-16.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPButton: UIView {
    let effectView = UIVisualEffectView( effect: UIBlurEffect( style: .dark ) )
    var button: UIButton!

    override var bounds: CGRect {
        didSet {
            if self.round {
                self.effectView.layer.cornerRadius = self.bounds.size.height / 2
            }
        }
    }
    var round = false {
        didSet {
            self.bounds = self.bounds.standardized
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    convenience init(image: UIImage? = nil, title: String? = nil) {
        let button = UIButton( type: .custom )
        self.init( subview: button )

        button.setImage( image, for: .normal )
        button.setTitle( title, for: .normal )
        button.setTitleColor( .lightText, for: .normal )
        button.contentEdgeInsets = UIEdgeInsets( top: 4, left: 4, bottom: 4, right: 4 )

        self.button = button
        self.round = true
    }

    init(subview: UIView) {
        super.init( frame: .zero )

        self.layoutMargins = .zero
        self.layer.shadowOffset = .zero
        self.layer.shadowRadius = 10
        self.layer.shadowOpacity = 0.5

        self.effectView.layer.masksToBounds = true
        self.effectView.layer.cornerRadius = 4

        self.addSubview( self.effectView )
        self.effectView.contentView.addSubview( subview )

        ViewConfiguration( view: self.effectView ).constrainToSuperview().activate()
        ViewConfiguration( view: subview )
                .constrainTo { self.layoutMarginsGuide.topAnchor.constraint( equalTo: $1.topAnchor ) }
                .constrainTo { self.layoutMarginsGuide.leadingAnchor.constraint( equalTo: $1.leadingAnchor ) }
                .constrainTo { self.layoutMarginsGuide.trailingAnchor.constraint( equalTo: $1.trailingAnchor ) }
                .constrainTo { self.layoutMarginsGuide.bottomAnchor.constraint( equalTo: $1.bottomAnchor ) }
                .activate()
    }
}
