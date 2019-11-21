//
// Created by Maarten Billemont on 2018-09-16.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class MPButton: MPEffectView {
    var identifier: String?
    var action:     ((UIEvent, MPButton) -> Void)?
    var tapEffect = true
    var image: UIImage? {
        didSet {
            DispatchQueue.main.perform {
                self.button.setImage( self.image, for: .normal )
                self.button.sizeToFit()
            }
        }
    }
    var title: String? {
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
                self.button.sizeToFit()
            }
        }
    }
    var size = Size.image_icon {
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
                self.button.sizeToFit()
            }
        }
    }
    let button = UIButton( type: .custom )

    private var stateObserver: Any?
    private lazy var squareButtonConstraint = self.button.widthAnchor.constraint( equalTo: self.button.heightAnchor )
                                                                     .with( priority: .defaultHigh )
    override var bounds: CGRect {
        didSet {
            self.setNeedsUpdateConstraints()
        }
    }

    // MARK: --- Life ---

    static func close(for prefix: String) -> MPButton {
        MPButton( identifier: "\(prefix) #close", title: "╳" )
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(identifier: String? = nil, image: UIImage? = nil, title: String? = nil,
         border: CGFloat = 1, background: Bool = true, dark: Bool = false, round: Bool = true, rounding: CGFloat = 4, dims: Bool = false,
         action: ((UIEvent, MPButton) -> Void)? = nil) {
        self.identifier = identifier
        self.action = action
        super.init( border: border, background: background, dark: dark, round: round, rounding: rounding, dims: false )

        self.button.setContentHuggingPriority( .defaultHigh + 1, for: .horizontal )
        self.button.setContentHuggingPriority( .defaultHigh + 1, for: .vertical )
        self.button.setContentCompressionResistancePriority( .defaultHigh + 1, for: .horizontal )
        self.button.setContentCompressionResistancePriority( .defaultHigh + 1, for: .vertical )
        self.button.setTitleColor( appConfig.theme.color.body.get(), for: .normal )
        self.button.titleLabel?.font = appConfig.theme.font.callout.get()
        self.button.setContentHuggingPriority( .defaultHigh, for: .vertical )
        self.button.addTarget( self, action: #selector( action(_:) ), for: .primaryActionTriggered )
        self.button.sizeToFit()

        self.stateObserver = self.button.observe( \UIButton.isSelected, options: .initial ) { _, _ in
            self.isSelected = self.button.isSelected
        }

        self.contentView.layoutMargins = .zero
        if #available( iOS 11.0, * ) {
            self.contentView.insetsLayoutMarginsFromSafeArea = false
        }

        self.contentView.addSubview( self.button )

        LayoutConfiguration( view: self.button )
                .constrain( margins: true )
                .activate()

        defer {
            self.image = image
            self.title = title
        }
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        self.systemLayoutSizeFitting( size )
    }

    @objc
    func action(_ event: UIEvent) {
        self.track()

        if self.tapEffect {
            MPTapEffectView().run( for: self )
        }

        self.action?( event, self )
    }

    func track() {
        if let identifier = self.identifier {
            MPTracker.shared.event( named: identifier )
        }
    }

    // MARK: --- Types ---

    enum Size {
        case text, text_icon, image_icon, small
    }
}

class MPTimedButton: MPButton {
    var timing: MPTracker.TimedEvent?

    override func track() {
        if let identifier = self.identifier {
            self.timing = MPTracker.shared.begin( named: identifier )
        }
    }
}
