//
// Created by Maarten Billemont on 2018-09-16.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPButton: UIView {
    public var round            = false {
        didSet {
            self.setNeedsUpdateConstraints()
        }
    }
    public var effectBackground = true {
        didSet {
            DispatchQueue.main.perform {
                self.effectView.effect = self.effectBackground ? UIBlurEffect( style: self.darkBackground ? .dark: .light ): nil
            }
        }
    }
    public var darkBackground   = false {
        didSet {
            DispatchQueue.main.perform {
                self.tintColor = self.darkBackground ? .white: .black
                self.effectBackground = self.effectBackground || self.effectBackground
//                self.layer.shadowColor = self.darkBackground ? UIColor.black.cgColor: UIColor.white.cgColor
            }
        }
    }
    public var title: String? {
        didSet {
            DispatchQueue.main.perform {
                self.button.setTitle( self.title, for: .normal )
                self.setNeedsUpdateConstraints()
            }
        }
    }

    private let      effectView = UIVisualEffectView()
    private(set) var button: UIButton!
    override var     bounds: CGRect {
        didSet {
            self.setNeedsUpdateConstraints()
        }
    }

    // MARK: --- Life ---

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
        self.button.setTitleShadowColor( .black, for: .normal )
        self.button.titleLabel?.font = UIFont.preferredFont( forTextStyle: .headline )
        self.button.titleLabel?.shadowOffset = CGSize( width: 0, height: -1 )
        self.button.addTarget( self, action: #selector( buttonAction ), for: .touchUpInside )

        defer {
            self.layoutMargins = .zero
            self.round = true
            self.title = title
        }
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

    override func updateConstraints() {
        self.effectView.layer.cornerRadius = self.round ? self.bounds.size.height / 2: 0

        if let button = self.button {
            if let title = title, title.count > 1 {
                button.contentEdgeInsets = UIEdgeInsets( top: 6, left: 12, bottom: 6, right: 12 )
            }
            else if let title = title, title.count == 1 {
                button.contentEdgeInsets = UIEdgeInsets( top: 12, left: 12, bottom: 12, right: 12 )
                button.widthAnchor.constraint( equalTo: button.heightAnchor ).isActive = true
            }
            else {
                button.contentEdgeInsets = UIEdgeInsets( top: 6, left: 6, bottom: 6, right: 6 )
            }
        }

        super.updateConstraints()
    }

    @objc
    func buttonAction() {
        MPTapEffectView( for: self.effectView ).run()
    }
}
