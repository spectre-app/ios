//
// Created by Maarten Billemont on 2018-09-16.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPButton: UIView {
    public var tapEffect = true
    public var round     = false {
        didSet {
            self.setNeedsUpdateConstraints()
        }
    }
    public var effectBackground = true {
        didSet {
            DispatchQueue.main.perform {
                if #available( iOS 13, * ) {
                    self.effectView.effect = self.effectBackground ? UIBlurEffect(
                            style: self.darkBackground ? .systemUltraThinMaterialDark: .systemUltraThinMaterialLight ): nil
                }
                else {
                    self.effectView.effect = self.effectBackground ? UIBlurEffect(
                            style: self.darkBackground ? .dark: .light ): nil
                }
            }
        }
    }
    public var darkBackground = false {
        didSet {
            DispatchQueue.main.perform {
                self.tintColor = self.darkBackground ? MPTheme.global.color.secondary.get(): MPTheme.global.color.backdrop.get()
                self.effectBackground = self.effectBackground || self.effectBackground
            }
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
                if let title = self.title, title.count > 1 {
                    self.size = .text
                }
                else if let title = self.title, title.count == 1 {
                    self.size = .icon
                }
                else {
                    self.size = .small
                }

                self.button.setTitle( self.title, for: .normal )
            }
        }
    }
    public var size = Size.icon {
        didSet {
            DispatchQueue.main.perform {
                switch self.size {
                    case .text:
                        self.button.contentEdgeInsets = UIEdgeInsets( top: 6, left: 12, bottom: 6, right: 12 )
                    case .icon:
                        self.button.contentEdgeInsets = UIEdgeInsets( top: 12, left: 12, bottom: 12, right: 12 )
                        self.button.widthAnchor.constraint( equalTo: self.button.heightAnchor ).isActive = true
                    case .small:
                        self.button.contentEdgeInsets = UIEdgeInsets( top: 6, left: 6, bottom: 6, right: 6 )
                }
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
        MPButton( title: "╳" )
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    convenience init(image: UIImage? = nil, title: String? = nil) {
        let button = UIButton( type: .custom )
        self.init( content: button )
        self.button = button

        self.button.setTitleShadowColor( UIColor.black.withAlphaComponent( 0.382 ), for: .normal )
        self.button.titleLabel?.shadowOffset = self.button.layer.shadowOffset
        self.button.layer.shadowOpacity = 0

        self.button.titleLabel?.font = MPTheme.global.font.headline.get()
        self.button.setContentHuggingPriority( .defaultHigh, for: .vertical )
        self.button.addAction( for: .touchUpInside ) { _, _ in
            if self.tapEffect {
                MPTapEffectView( for: self.effectView ).run()
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
        super.init( frame: .zero )

        if #available( iOS 11.0, * ) {
            self.insetsLayoutMarginsFromSafeArea = false
        }

        self.effectView.backgroundColor = MPTheme.global.color.glow.get()?.withAlphaComponent( 0.382 )
        self.effectView.layer.borderWidth = 2
        self.effectView.layer.borderColor = MPTheme.global.color.body.get()?.cgColor
        self.effectView.layer.masksToBounds = true

        content.layer.shadowRadius = 0
        content.layer.shadowOpacity = 0.382
        content.layer.shadowColor = MPTheme.global.color.shadow.get()?.cgColor
        content.layer.shadowOffset = CGSize( width: 0, height: 1 )

        self.addSubview( self.effectView )
        self.effectView.contentView.addSubview( content )

        LayoutConfiguration( view: self.effectView ).constrainToOwner().activate()
        LayoutConfiguration( view: content ).constrain( toMarginsOf: self ).activate()

        defer {
            self.effectBackground = true
            self.darkBackground = false
        }
    }

    override func updateConstraints() {
        self.effectView.layer.cornerRadius = self.round ? self.bounds.size.height / 2: 4
        super.updateConstraints()
    }

    enum Size {
        case text, icon, small
    }
}
