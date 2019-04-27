//
// Created by Maarten Billemont on 2018-09-16.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPButton: UIView {
    let effectView = UIVisualEffectView()
    var button: UIButton!

    override var bounds: CGRect {
        didSet {
            if self.round {
                self.effectView.layer.cornerRadius = self.bounds.size.height / 2
            }
        }
    }
    var round            = false {
        didSet {
            self.bounds = self.bounds.standardized
        }
    }
    var effectBackground = true {
        didSet {
            self.effectView.effect = self.effectBackground ? UIBlurEffect( style: self.darkBackground ? .dark : .light ) : nil
        }
    }
    var darkBackground   = false {
        didSet {
            self.tintColor = self.darkBackground ? .white : .black
            self.effectBackground = self.effectBackground || self.effectBackground
//            self.layer.shadowColor = self.darkBackground ? UIColor.black.cgColor: UIColor.white.cgColor
        }
    }

    // MARK: - Life

    static func closeButton() -> MPButton {
        return MPButton( title: "╳" )
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    convenience init(image: UIImage? = nil, title: String? = nil) {
        let button = UIButton( type: .custom )
        self.init( content: button )
        self.button = button

        self.button.setImage( image, for: .normal )
        self.button.setTitle( title, for: .normal )
        self.button.setTitleShadowColor( .black, for: .normal )
        self.button.titleLabel?.font = UIFont.preferredFont( forTextStyle: .headline )
        self.button.titleLabel?.shadowOffset = CGSize( width: 0, height: -1 )
        self.button.addTarget( self, action: #selector( buttonAction ), for: .touchUpInside )

        if let title = title, title.count > 1 {
            self.button.contentEdgeInsets = UIEdgeInsets( top: 6, left: 12, bottom: 6, right: 12 )
        }
        else if let title = title, title.count == 1 {
            self.button.contentEdgeInsets = UIEdgeInsets( top: 12, left: 12, bottom: 12, right: 12 )
            self.button.widthAnchor.constraint( equalTo: self.button.heightAnchor ).isActive = true
        }
        else {
            self.button.contentEdgeInsets = UIEdgeInsets( top: 6, left: 6, bottom: 6, right: 6 )
        }

        self.layoutMargins = .zero
        self.round = true
    }

    init(content: UIView) {
        super.init( frame: .zero )

        if #available( iOS 11.0, * ) {
            self.insetsLayoutMarginsFromSafeArea = false
        }

        self.layer.shadowRadius = 8
        self.layer.shadowOpacity = 0.382

        self.effectView.layer.masksToBounds = true
        self.effectView.layer.cornerRadius = 4

        self.addSubview( self.effectView )
        self.effectView.contentView.addSubview( content )

        ViewConfiguration( view: self.effectView ).constrainToSuperview().activate()
        ViewConfiguration( view: content ).constrain( toMarginsOf: self ).activate()

        defer {
            self.effectBackground = true
            self.darkBackground = false
        }
    }

    @objc
    func buttonAction() {
        MPTapEffectView( for: self.effectView ).animate()
    }
}
