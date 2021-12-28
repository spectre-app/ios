// =============================================================================
// Created by Maarten Billemont on 2019-10-12.
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

class EffectView: UIView, ThemeObserver {
    public var   borderWidth:         CGFloat {
        didSet {
            if self.borderWidth != oldValue {
                self.update()
            }
        }
    }
    public var   isBackground:        Bool {
        didSet {
            if self.isBackground != oldValue {
                self.update()
            }
        }
    }
    public var   isCircular:          Bool {
        didSet {
            if self.isCircular != oldValue {
                self.update()
            }
        }
    }
    public var   rounding:            CGFloat {
        didSet {
            if self.rounding != oldValue {
                self.update()
            }
        }
    }
    public var   isDimmedBySelection: Bool {
        didSet {
            if self.isDimmedBySelection != oldValue {
                self.update()
            }
        }
    }
    public var   isSelected = false {
        didSet {
            if self.isSelected != oldValue {
                self.update()
            }
        }
    }
    public var   isDimmed:            Bool {
        self.isDimmedBySelection && !self.isSelected
    }
    override var frame:               CGRect {
        didSet {
            if self.isCircular && self.frame != oldValue {
                self.update()
            }
        }
    }
    override var bounds:              CGRect {
        didSet {
            if self.isCircular && self.bounds != oldValue {
                self.update()
            }
        }
    }
    var borderColor: UIColor? {
        didSet {
            if self.borderColor != oldValue {
                self.update()
            }
        }
    }
    var contentView: UIView {
        self.vibrancyEffectView.contentView
    }
    override var layoutMargins:   UIEdgeInsets {
        get {
            self.contentView.layoutMargins
        }
        set {
            self.contentView.layoutMargins = newValue
        }
    }
    override var backgroundColor: UIColor? {
        get {
            self.contentView.backgroundColor
        }
        set {
            self.contentView.backgroundColor = newValue
        }
    }

    private var blurEffect:     UIBlurEffect? {
        didSet {
            self.blurEffectView.effect = self.blurEffect
//            if let blurEffect = self.blurEffect {
//                self.vibrancyEffect = UIVibrancyEffect( blurEffect: blurEffect, style: .fill )
//            }
//            else {
//                self.vibrancyEffect = nil
//            }
        }
    }
    private var vibrancyEffect: UIVibrancyEffect? {
        didSet {
            self.vibrancyEffectView.effect = self.vibrancyEffect
        }
    }
    private lazy var blurEffectView     = UIVisualEffectView( effect: self.blurEffect )
    private lazy var vibrancyEffectView = UIVisualEffectView( effect: self.vibrancyEffect )
    private let innerShadowLayer = InnerShadowLayer()

    init(border: CGFloat = 1, background: Bool = true, circular: Bool = false, rounding: CGFloat = 20, dims: Bool = false) {
        self.borderWidth = border
        self.isBackground = background
        self.isCircular = circular
        self.rounding = rounding
        self.isDimmedBySelection = dims

        super.init( frame: .zero )

        // - View
        self => \.borderColor => Theme.current.color.mute

        self.layer.masksToBounds = true
        self.layer.shadowRadius = 0
        self.layer.shadowOpacity = .short
        self.layer => \.shadowColor => Theme.current.color.shadow
        self.layer.shadowOffset = CGSize( width: 0, height: 1 )

        self.contentView.insetsLayoutMarginsFromSafeArea = false
        self.update()

        // - Hierarchy
        self.blurEffectView.contentView.addSubview( self.vibrancyEffectView )
        self.addSubview( self.blurEffectView )
        self.layer.addSublayer( self.innerShadowLayer )

        // - Layout
        LayoutConfiguration( view: self.vibrancyEffectView )
                .constrain( as: .box ).activate()
        LayoutConfiguration( view: self.blurEffectView )
                .constrain( as: .box ).activate()
    }

    convenience init(content: UIView, border: CGFloat = 1, background: Bool = true,
                     circular: Bool = false, rounding: CGFloat = 4, dims: Bool = false) {
        self.init( border: border, background: background, circular: circular, rounding: rounding, dims: false )

        // - View
        self.addContentView( content )

        // - Layout
        LayoutConfiguration( view: content )
                .constrain( as: .box, margin: true ).activate()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove( toWindow: newWindow )

        if newWindow != nil {
            Theme.current.observers.register( observer: self )
        }
        else {
            Theme.current.observers.unregister( observer: self )
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.innerShadowLayer.frame = self.innerShadowLayer.superlayer?.bounds ?? .zero
    }

    func addContentView(_ view: UIView) {
        self.contentView.addSubview( view )
    }

    // MARK: - ThemeObserver

    func didChange(theme: Theme) {
        self.update()
    }

    // MARK: - Updatable

    private func update() {
        DispatchQueue.main.perform {
            if self.isBackground {
                self.innerShadowLayer.opacity = .on
                self.blurEffect = UIBlurEffect( style: self.isDimmed ? .systemUltraThinMaterial : .systemThinMaterial )
            }
            else {
                self.innerShadowLayer.opacity = .off
                self.blurEffect = nil
            }

            self.layer.cornerCurve = self.isCircular ? .circular : .continuous
            self.layer.cornerRadius = self.isCircular ? min( self.bounds.width, self.bounds.height ) / 2 : self.rounding
            self.layer.borderWidth = self.borderWidth
            self.layer.borderColor = (!self.isDimmedBySelection || self.isDimmed ? self.borderColor :
                                      Theme.current.color.body.get())?.cgColor
            self.blurEffectView.alpha = self.isDimmed ? .long : .on
            self.innerShadowLayer.cornerRadius = self.layer.cornerRadius
        }
    }
}
