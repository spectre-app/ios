//
// Created by Maarten Billemont on 2019-03-31.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPToggleButton: UIView {
    private let button     = UIButton()
    private let checkLabel = UILabel()
    private lazy var contentView = MPEffectView( content: self.button )

    var tapEffect = true
    var tracking: MPTracking?
    var action:     (Bool) -> Bool?
    var isSelected: Bool {
        get {
            self.button.isSelected
        }
        set {
            DispatchQueue.main.perform {
                self.button.isSelected = newValue

                UIView.animate( withDuration: .short ) {
                    self.button.alpha = self.isSelected ? .on: .short
//                    self.button.imageView?.alpha = self.isSelected ? .on: .short
                    self.checkLabel => \.textColor => Theme.current.color.body.transform { [unowned self] in
                        $0?.with( alpha: self.isSelected ? .on: .off )
                    }
                    self.checkLabel.layer.borderWidth = self.isSelected ? 1.5: 1
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

    init(track: MPTracking? = nil, action: @escaping (Bool) -> Bool?) {
        self.tracking = track
        self.action = action
        super.init( frame: .zero )

        self.checkLabel => \.font => Theme.current.font.callout
        self.checkLabel => \.textColor => Theme.current.color.body
        self.checkLabel => \.backgroundColor => Theme.current.color.panel
        self.checkLabel.layer => \.borderColor => Theme.current.color.secondary
        self.checkLabel.layer.masksToBounds = true
        self.checkLabel.textAlignment = .center
        self.checkLabel.text = "✓"

        self.contentView.isRound = true

        self.button.contentEdgeInsets = .border( 12 )
        self.button.action( for: .primaryActionTriggered ) { [unowned self] in
            self.action( !self.isSelected ).flatMap { self.isSelected = $0 }
            self.track()

            if self.tapEffect {
                MPTapEffectView().run( for: self )
            }

            MPFeedback.shared.play( .trigger )
        }

        self.layoutMargins = self.button.contentEdgeInsets

        self.addSubview( self.contentView )
        self.addSubview( self.checkLabel )

        self.widthAnchor.constraint( equalTo: self.heightAnchor ).isActive = true
        self.widthAnchor.constraint( equalToConstant: 70 ).with( priority: .defaultHigh ).isActive = true

        LayoutConfiguration( view: self.contentView )
                .constrain( margins: true )
                .activate()
        LayoutConfiguration( view: self.checkLabel )
                .constrainTo { $1.widthAnchor.constraint( equalTo: $1.heightAnchor ) }
                .constrainTo { $1.centerXAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerXAnchor ) }
                .constrainTo { $1.centerYAnchor.constraint( equalTo: $0.layoutMarginsGuide.bottomAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
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
            MPTracker.shared.event( track: tracking.with( parameters: [ "value": self.isSelected ] ) )
        }
    }

    func action(for controlEvents: UIControl.Event, _ action: @escaping () -> Void) {
        self.button.action( for: controlEvents, action )
    }

    func action(for controlEvents: UIControl.Event, _ action: @escaping (UIEvent) -> Void) {
        self.button.action( for: controlEvents, action )
    }
}
