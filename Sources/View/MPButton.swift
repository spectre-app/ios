//
// Created by Maarten Billemont on 2018-09-16.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class MPButton: MPEffectView {
    var identifier:      String?
    var action:          ((UIEvent, MPButton) -> Void)?
    var tapEffect = true
    var image:           UIImage? {
        didSet {
            if self.image != oldValue {
                self.update()
            }
        }
    }
    var title:           String? {
        didSet {
            if self.title != oldValue {
                self.update()
            }
        }
    }
    var attributedTitle: NSAttributedString? {
        didSet {
            if self.attributedTitle != oldValue {
                self.update()
            }
        }
    }

    private var stateObserver: Any?
    private let button = UIButton( type: .custom )
    private lazy var squareButtonConstraint = self.button.widthAnchor.constraint( equalTo: self.button.heightAnchor )
                                                                     .with( priority: UILayoutPriority( 900 ) )

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(identifier: String? = nil, image: UIImage? = nil, title: String? = nil, attributedTitle: NSAttributedString? = nil,
         border: CGFloat = 1, background: Bool = true, round: Bool = true, rounding: CGFloat = 4, dims: Bool = false,
         action: ((UIEvent, MPButton) -> Void)? = nil) {
        self.identifier = identifier
        self.action = action
        super.init( border: border, background: background, round: round, rounding: rounding, dims: false )

        self.image = image
        self.title = title
        self.attributedTitle = attributedTitle

        // - View
        self.layoutMargins = .zero
        self.button.titleLabel?.numberOfLines = 0
        self.button.titleLabel?.textAlignment = .center
        self.button.action( for: .primaryActionTriggered ) { [unowned self] in
            self.track()

            if self.tapEffect {
                MPTapEffectView().run( for: self )
            }

            self.action?( $0, self )
        }
        self.button.setContentHuggingPriority( .defaultHigh + 1, for: .horizontal )
        self.button.setContentHuggingPriority( .defaultHigh + 1, for: .vertical )
        self.button.setContentCompressionResistancePriority( .defaultHigh + 1, for: .horizontal )
        self.button.setContentCompressionResistancePriority( .defaultHigh + 1, for: .vertical )
        self.button.setContentHuggingPriority( .defaultHigh, for: .vertical )
        self.stateObserver = self.button.observe( \.isSelected, options: .initial ) { [unowned self] _, _ in
            self.isSelected = self.button.isSelected
        }
        self.update()

        // - Hierarchy
        self.addContentView( self.button )

        // - Layout
        LayoutConfiguration( view: self.button )
                .constrain( margins: true )
                .activate()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        self.systemLayoutSizeFitting( size )
    }

    func track() {
        if let identifier = self.identifier {
            MPTracker.shared.event( named: identifier )
        }
    }

    func action(for controlEvents: UIControl.Event, _ action: @escaping () -> Void) {
        self.button.action( for: controlEvents, action )
    }

    func action(for controlEvents: UIControl.Event, _ action: @escaping (UIEvent) -> Void) {
        self.button.action( for: controlEvents, action )
    }

    private func update() {
        DispatchQueue.main.perform {
            if self.title?.count ?? 0 == 1 || self.attributedTitle?.length ?? 0 == 1 ||
                       (self.attributedTitle?.length ?? 0 == 3 && self.attributedTitle == NSAttributedString.icon( self.attributedTitle?.string.first?.description ?? "" )) {
                self.button.contentEdgeInsets = UIEdgeInsets( top: 12, left: 12, bottom: 12, right: 12 )
                self.squareButtonConstraint.isActive = true
            }
            else {
                self.button.contentEdgeInsets = UIEdgeInsets( top: 6, left: 12, bottom: 6, right: 12 )
                self.squareButtonConstraint.isActive = false
            }

            self.button.setImage( self.image, for: .normal )
            self.button.setTitle( self.title, for: .normal )
            self.button.setAttributedTitle( self.attributedTitle, for: .normal )
            self.button => \.titleLabel!.font => Theme.current.font.callout
            //self.button => \.currentAttributedTitle => .font => Theme.current.font.callout
            self.button => \.currentAttributedTitle => .foregroundColor => Theme.current.color.body
            self.button => \.currentAttributedTitle => .strokeColor => Theme.current.color.secondary
            self.button => \.currentTitleColor => Theme.current.color.body
            self.button.sizeToFit()
        }
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
