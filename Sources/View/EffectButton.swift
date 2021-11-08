// =============================================================================
// Created by Maarten Billemont on 2018-09-16.
// Copyright (c) 2018 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import UIKit

class EffectButton: EffectView {
    var tracking:        Tracking?
    var action:          ((EffectButton) -> Void)?
    var image:           UIImage? {
        didSet {
            if self.image != oldValue {
                self.update()
            }
        }
    }
    var title:           String? {
        get {
            self.button.currentTitle
        }
        set {
            self.button.setTitle( newValue, for: .normal )
        }
    }
    var attributedTitle: NSAttributedString? {
        get {
            self.button.currentAttributedTitle
        }
        set {
            self.button.setAttributedTitle( newValue, for: .normal )
        }
    }

    var padded    = true {
        didSet {
            if self.padded != oldValue {
                self.update()
            }
        }
    }
    var tapEffect = true

    let button = UIButton( type: .custom )

    private var stateObserver: Any?
    private lazy var squareButtonConstraint = self.button.widthAnchor.constraint( equalTo: self.button.heightAnchor )
                                                                     .with( priority: .defaultHigh + 2 )

    // MARK: - Life

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    convenience init(track: Tracking? = nil, image: UIImage? = nil, title: String? = nil, attributedTitle: NSAttributedString? = nil,
                     border: CGFloat = 0, background: Bool = true, square: Bool = false, circular: Bool = false, rounding: CGFloat = 12,
                     dims: Bool = false, action: @escaping () -> Void) {
        self.init( track: track, image: image, title: title, attributedTitle: attributedTitle,
                   border: border, background: background, square: square, circular: circular, rounding: rounding,
                   dims: dims ) { _ in action() }
    }

    init(track: Tracking? = nil, image: UIImage? = nil, title: String? = nil, attributedTitle: NSAttributedString? = nil,
         border: CGFloat = 1, background: Bool = true, square: Bool = false, circular: Bool = false, rounding: CGFloat = 12,
         dims: Bool = false, action: ((EffectButton) -> Void)? = nil) {
        self.tracking = track
        self.action = action
        super.init( border: border, background: background, circular: circular, rounding: rounding, dims: dims )

        self.image = image
        self.title = title
        self.attributedTitle = attributedTitle
        self.squareButtonConstraint.isActive = square

        // - View
        self.layoutMargins = .zero
        self.button.titleLabel?.textAlignment = .center
        self.button.titleLabel?.allowsDefaultTighteningForTruncation = true
        self.button.action( for: .primaryActionTriggered ) { [unowned self] in
            self.activate()
        }
        self.button.setContentHuggingPriority( .defaultHigh + 1, for: .vertical )
        self.button.setContentHuggingPriority( .defaultHigh + 1, for: .horizontal )
        self.button.setContentCompressionResistancePriority( .defaultHigh + 2, for: .vertical )
        self.button.setContentCompressionResistancePriority( .defaultHigh + 2, for: .horizontal )
        self.stateObserver = self.button.observe( \.isSelected, options: .initial ) { [unowned self] _, _ in
            self.isSelected = self.button.isSelected
        }
        self.update()

        // - Hierarchy
        self.addContentView( self.button )

        // - Layout
        LayoutConfiguration( view: self.button )
                .constrain( as: .box, margin: true ).activate()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        self.systemLayoutSizeFitting( size )
    }

    func activate() {
        self.track()

        if self.tapEffect {
            TapEffectView().run( for: self )
        }

        self.action?( self )
    }

    func track() {
        if let tracking = self.tracking {
            Tracker.shared.event( track: tracking )
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
            if !self.padded {
                self.button.contentEdgeInsets = .zero
            }
            else if self.squareButtonConstraint.isActive {
                self.button.contentEdgeInsets = .border( 12 )
            }
            else {
                self.button.contentEdgeInsets = UIEdgeInsets( top: 6, left: 12, bottom: 6, right: 12 )
            }

            self.button.setImage( self.image, for: .normal )
            self.button => \.titleLabel!.font => Theme.current.font.callout
            //self.button => \.currentAttributedTitle => .font => Theme.current.font.callout
            self.button => \.currentAttributedTitle => .foregroundColor => Theme.current.color.body
            self.button => \.currentAttributedTitle => .strokeColor => Theme.current.color.secondary
            self.button => \.currentTitleColor => Theme.current.color.body
            self.button.sizeToFit()
        }
    }
}

class TimedButton: EffectButton {
    var timing: Tracker.TimedEvent?

    override func track() {
        if let tracking = self.tracking {
            self.timing = Tracker.shared.begin( track: tracking )
        }
    }
}
