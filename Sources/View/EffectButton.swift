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
    var action:          (@MainActor (EffectButton) async -> Void)?
    var image:           UIImage? {
        didSet {
            if self.image != oldValue {
                self.update()
            }
        }
    }
    var title:           String? {
        get {
            self.buttonConfiguration.title
        }
        set {
            self.buttonConfiguration.title = newValue
        }
    }
    var attributedTitle: NSAttributedString? {
        get {
            self.buttonConfiguration.attributedTitle.flatMap(NSAttributedString.init)
        }
        set {
            self.buttonConfiguration.attributedTitle = newValue.flatMap(AttributedString.init)
        }
    }
    override var debugDescription: String { "EffectButton{title: \(self.title ?? ""), action: \(self.tracking?.action ?? "")}" }

    var padded    = true {
        didSet {
            if self.padded != oldValue {
                self.update()
            }
        }
    }
    var tapEffect = true

    lazy var button = UIButton(configuration: self.buttonConfiguration)
    lazy var buttonConfiguration = UIButton.Configuration.plain() {
        didSet {
            self.button.configuration = self.buttonConfiguration
        }
    }

    private var stateObserver: Any?
    private lazy var squareButtonConstraint = self.button.widthAnchor.constraint( equalTo: self.button.heightAnchor )
                                                  .with( priority: .defaultHigh + 2 )

    // MARK: - Life

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    convenience init(track: Tracking? = nil, image: UIImage? = nil, title: String? = nil, attributedTitle: NSAttributedString? = nil,
                     border: CGFloat = 0, background: Bool = true, square: Bool = false, circular: Bool = false, rounding: CGFloat = 12,
                     dims: Bool = false, action: @escaping @MainActor () async -> Void) {
        self.init( track: track, image: image, title: title, attributedTitle: attributedTitle,
                   border: border, background: background, square: square, circular: circular, rounding: rounding,
                   dims: dims ) { _ in await action() }
    }

    init(track: Tracking? = nil, image: UIImage? = nil, title: String? = nil, attributedTitle: NSAttributedString? = nil,
         border: CGFloat = 1, background: Bool = true, square: Bool = false, circular: Bool = false, rounding: CGFloat = 12,
         dims: Bool = false, action: (@MainActor (EffectButton) async -> Void)? = nil) {
        self.tracking = track
        self.action = action
        super.init( border: border, background: background, circular: circular, rounding: rounding, dims: dims )

        self.image = image
        self.title = title
        self.attributedTitle = attributedTitle
        self.squareButtonConstraint.isActive = square

        // - View
        self.layoutMargins = .zero
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
        LayoutConfiguration( view: button )
            .constrain( as: .box, margin: true ).activate()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        self.systemLayoutSizeFitting( size )
    }

    func activate() {
        Task {
            self.track()

            if self.tapEffect {
                TapEffectView().run( for: self )
            }

            await self.action?( self )
        }
    }

    func track() {
        if let tracking = self.tracking {
            Tracker.shared.event( track: tracking )
        }
    }

    func action(for controlEvents: UIControl.Event, _ action: @MainActor @escaping () async -> Void) {
        self.action = { _ in await action() }
    }

    func action(for controlEvents: UIControl.Event, _ action: @MainActor @escaping (EffectButton) async -> Void) {
        self.action = action
    }

    private func update() {
        self.buttonConfiguration.titleAlignment = .center
        if !self.padded {
            self.buttonConfiguration.contentInsets = .zero
        }
        else if self.squareButtonConstraint.isActive {
            self.buttonConfiguration.contentInsets = .init( top: 12, leading: 12, bottom: 12, trailing: 12 )
        }
        else {
            self.buttonConfiguration.contentInsets = .init( top: 6, leading: 12, bottom: 6, trailing: 12 )
        }

        self.buttonConfiguration.image = self.image
//        self => \.buttonConfiguration.titleLabel!.font => Theme.current.font.callout
        self => \.buttonConfiguration.attributedTitle => .font => Theme.current.font.callout
        self => \.buttonConfiguration.attributedTitle => .foregroundColor => Theme.current.color.body
        self => \.buttonConfiguration.attributedTitle => .strokeColor => Theme.current.color.secondary
//        self => \.buttonConfiguration.titleColor => Theme.current.color.body
        self.button.sizeToFit()
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
