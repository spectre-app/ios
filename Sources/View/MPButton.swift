//
// Created by Maarten Billemont on 2018-09-16.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPButton: MPEffectView {
    public var tapEffect = true
    public var round     = false {
        didSet {
            self.setNeedsUpdateConstraints()
        }
    }
    public var image: UIImage? {
        didSet {
            DispatchQueue.main.perform {
                self.button.setImage( self.image, for: .normal )
            }
        }
    }
    public var title: String? {
        didSet {
            DispatchQueue.main.perform {
                if self.title?.count ?? 0 > 1 {
                    self.size = .text
                }
                else if self.title?.count ?? 0 == 1 {
                    self.size = .text_icon
                }
                else if self.title?.isEmpty ?? true {
                    self.size = .image_icon
                }
                else {
                    self.size = .small
                }

                self.button.setTitle( self.title, for: .normal )
            }
        }
    }
    public var size = Size.image_icon {
        didSet {
            DispatchQueue.main.perform {
                switch self.size {
                    case .text:
                        self.button.contentEdgeInsets = UIEdgeInsets( top: 6, left: 12, bottom: 6, right: 12 )
                        self.squareButtonConstraint.isActive = false
                    case .text_icon:
                        self.button.contentEdgeInsets = UIEdgeInsets( top: 12, left: 12, bottom: 12, right: 12 )
                        self.squareButtonConstraint.isActive = true
                    case .image_icon:
                        self.button.contentEdgeInsets = UIEdgeInsets( top: 4, left: 4, bottom: 4, right: 4 )
                        self.squareButtonConstraint.isActive = true
                    case .small:
                        self.button.contentEdgeInsets = UIEdgeInsets( top: 3, left: 5, bottom: 3, right: 5 )
                        self.squareButtonConstraint.isActive = false
                }
            }
        }
    }
    override var effectBackground: Bool {
        didSet {
            self.layer.borderWidth = self.effectBackground ? 1.5 : 0
        }
    }
    private(set) var button: UIButton!
    private lazy var squareButtonConstraint = self.button.widthAnchor.constraint( equalTo: self.button.heightAnchor )
    override var     bounds: CGRect {
        didSet {
            self.setNeedsUpdateConstraints()
        }
    }

    // MARK: --- Life ---

    static func closeButton() -> MPButton {
        MPButton( title: "╳" )
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    convenience init(image: UIImage? = nil, title: String? = nil) {
        let button = UIButton( type: .custom )
        self.init( content: button )
        self.button = button

        self.button.setTitleShadowColor( MPTheme.global.color.shadow.get(), for: .normal )
        self.button.titleLabel?.shadowOffset = self.button.layer.shadowOffset
        self.button.layer.shadowOpacity = 0

        self.button.titleLabel?.font = MPTheme.global.font.callout.get()
        self.button.setContentHuggingPriority( .defaultHigh, for: .vertical )
        self.button.addAction( for: .touchUpInside ) { _, _ in
            if self.tapEffect {
                MPTapEffectView( for: self ).run()
            }
        }

        defer {
            self.layoutMargins = .zero
            self.round = true
            self.image = image
            self.title = title
        }
    }

    init(content: UIView) {
        super.init()

        if #available( iOS 11.0, * ) {
            self.insetsLayoutMarginsFromSafeArea = false
        }

        self.layer.borderColor = MPTheme.global.color.body.get()?.cgColor
        self.layer.masksToBounds = true

        content.layer.shadowRadius = 0
        content.layer.shadowOpacity = 1
        content.layer.shadowColor = MPTheme.global.color.shadow.get()?.cgColor
        content.layer.shadowOffset = CGSize( width: 0, height: 1 )

        self.contentView.addSubview( content )

        LayoutConfiguration( view: content ).constrain( toMarginsOf: self ).activate()

        defer {
            self.darkBackground = false
            self.effectBackground = true
        }
    }

    override func updateConstraints() {
        self.layer.cornerRadius = self.round ? self.bounds.size.height / 2: 4
        super.updateConstraints()
    }

    enum Size {
        case text, text_icon, image_icon, small
    }
}
