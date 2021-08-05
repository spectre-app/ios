// =============================================================================
// Created by Maarten Billemont on 2019-03-31.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import UIKit

class EffectToggleButton: UIView {
    private let button     = UIButton()
    private let checkLabel = UILabel()
    private lazy var contentView = EffectView( dims: true )

    var tapEffect = true
    var tracking: Tracking?
    var action:   (Bool) -> Bool?
    var isSelected: Bool {
        get {
            self.button.isSelected
        }
        set {
            DispatchQueue.main.perform {
                self.button.isSelected = newValue
                self.contentView.isSelected = newValue

                UIView.animate( withDuration: .short ) {
                    self.button.alpha = self.isSelected ? .on: .long
                    self.checkLabel => \.textColor => Theme.current.color.body.transform { [unowned self] in
                        $0?.with( alpha: self.isSelected ? .on: .off )
                    }
                    self.checkLabel.layer => \.borderColor => (self.isSelected ? Theme.current.color.body: Theme.current.color.mute)
                }
            }
        }
    }
    var isEnabled: Bool {
        get {
            self.button.isEnabled
        }
        set {
            self.button.isEnabled = newValue
            self.tintAdjustmentMode = newValue ? .automatic: .dimmed
        }
    }
    var image:     UIImage? {
        get {
            self.button.currentImage
        }
        set {
            self.button.setImage( newValue, for: .normal )
        }
    }
    var title:     String? {
        get {
            self.button.currentTitle
        }
        set {
            self.button.setTitle( newValue, for: .normal )
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(track: Tracking? = nil, action: @escaping (Bool) -> Bool?) {
        self.tracking = track
        self.action = action
        super.init( frame: .zero )

        // - View
        self.layoutMargins = UIEdgeInsets( top: 0, left: 0, bottom: 12, right: 0 )
        self.insetsLayoutMarginsFromSafeArea = false

        self.checkLabel => \.font => Theme.current.font.callout
        self.checkLabel => \.textColor => Theme.current.color.body
        self.checkLabel => \.backgroundColor => Theme.current.color.panel
        self.checkLabel.layer => \.borderColor => Theme.current.color.mute
        self.checkLabel.layer.borderWidth = 1
        self.checkLabel.layer.masksToBounds = true
        self.checkLabel.textAlignment = .center
        self.checkLabel.text = "✓"

        self.button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 20, right: 8)
        self.button.action( for: .primaryActionTriggered ) { [unowned self] in
            self.action( !self.isSelected ).flatMap { self.isSelected = $0 }
            self.track()

            if self.tapEffect {
                TapEffectView().run( for: self )
            }

            Feedback.shared.play( .trigger )
        }

        // - Hierarchy
        self.addSubview( self.contentView )
        self.addSubview( self.checkLabel )
        self.addSubview( self.button )

        // - Layout
        self.heightAnchor.constraint( equalToConstant: 88 ).with( priority: .defaultHigh + 1 ).isActive = true

        LayoutConfiguration( view: self.button )
                .hugging( horizontal: .defaultHigh, vertical: .defaultHigh )
                .constrain( as: .box ).activate()
        LayoutConfiguration( view: self.contentView )
                .constrain { $1.widthAnchor.constraint( equalTo: $1.heightAnchor ) }
                .constrain( as: .box, margin: true ).activate()
        LayoutConfiguration( view: self.checkLabel )
                .constrain { $1.widthAnchor.constraint( equalTo: $1.heightAnchor ) }
                .constrain { $1.centerXAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerXAnchor ) }
                .constrain { $1.centerYAnchor.constraint( equalTo: $0.layoutMarginsGuide.bottomAnchor ) }
                .constrain { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                .activate()

        defer {
            self.isSelected = false
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.checkLabel.layer.cornerRadius = self.checkLabel.bounds.width / 2
    }

    func track() {
        if let tracking = self.tracking {
            Tracker.shared.event( track: tracking.with( parameters: [ "value": self.isSelected ] ) )
        }
    }

    func action(for controlEvents: UIControl.Event, _ action: @escaping () -> Void) {
        self.button.action( for: controlEvents, action )
    }

    func action(for controlEvents: UIControl.Event, _ action: @escaping (UIEvent) -> Void) {
        self.button.action( for: controlEvents, action )
    }
}
