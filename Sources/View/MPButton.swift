//
// Created by Maarten Billemont on 2018-09-16.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPButton: UIButton {
    override var bounds: CGRect {
        didSet {
            self.layer.cornerRadius = self.bounds.size.height / 2
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init() {
        super.init( frame: CGRect() )

        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOffset = .zero
        self.layer.shadowRadius = 10
        self.layer.shadowOpacity = 1
        self.setTitleColor( .lightText, for: .normal )
        self.backgroundColor = UIColor( white: 0.1, alpha: 0.9 )
        self.contentEdgeInsets = UIEdgeInsetsMake( 4, 8, 4, 12 )
    }
}
