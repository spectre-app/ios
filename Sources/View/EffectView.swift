//
// Created by Maarten Billemont on 2019-10-12.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

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
    override var layoutMargins:   UIEdgeInsets {
        get {
            self.vibrancyEffectView.contentView.layoutMargins
        }
        set {
            self.vibrancyEffectView.contentView.layoutMargins = newValue
        }
    }
    override var backgroundColor: UIColor? {
        get {
            self.vibrancyEffectView.contentView.backgroundColor
        }
        set {
            self.vibrancyEffectView.contentView.backgroundColor = newValue
        }
    }

    private var blurEffect:     UIBlurEffect? {
        didSet {
            self.blurEffectView.effect = self.blurEffect
//            if let blurEffect = self.blurEffect {
//                if #available( iOS 13, * ) {
//                    self.vibrancyEffect = UIVibrancyEffect( blurEffect: blurEffect, style: .fill )
//                }
//                else {
//                    self.vibrancyEffect = UIVibrancyEffect( blurEffect: blurEffect )
//                }
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

    init(border: CGFloat = 1.5, background: Bool = true, circular: Bool = false, rounding: CGFloat = 4, dims: Bool = false) {
        self.borderWidth = border
        self.isBackground = background
        self.isCircular = circular
        self.rounding = rounding
        self.isDimmedBySelection = dims

        super.init( frame: .zero )

        // - View
        self => \.borderColor => Theme.current.color.mute

        self.blurEffectView.layer.masksToBounds = true
        self.blurEffectView.layer.shadowRadius = 0
        self.blurEffectView.layer.shadowOpacity = .short
        self.blurEffectView.layer => \.shadowColor => Theme.current.color.shadow
        self.blurEffectView.layer.shadowOffset = CGSize( width: 0, height: 1 )

        self.vibrancyEffectView.contentView.insetsLayoutMarginsFromSafeArea = false
        self.update()

        // - Hierarchy
        self.blurEffectView.contentView.addSubview( self.vibrancyEffectView )
        self.addSubview( self.blurEffectView )

        // - Layout
        LayoutConfiguration( view: self.vibrancyEffectView )
                .constrain( as: .box ).activate()
        LayoutConfiguration( view: self.blurEffectView )
                .constrain( as: .box ).activate()
    }

    convenience init(content: UIView, border: CGFloat = 1.5, background: Bool = true, round: Bool = false, rounding: CGFloat = 4, dims: Bool = false) {
        self.init( border: border, background: background, circular: round, rounding: rounding, dims: false )

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

    func addContentView(_ view: UIView) {
        self.vibrancyEffectView.contentView.addSubview( view )
    }

    // MARK: --- ThemeObserver ---

    func didChangeTheme() {
        self.setNeedsDisplay()
    }

    // MARK: --- Updatable ---

    private func update() {
        DispatchQueue.main.perform {
            if self.isBackground {
                self.blurEffect = UIBlurEffect( style: {
                    if #available( iOS 13, * ) {
                        return self.isDimmed ? .systemUltraThinMaterial: .systemThinMaterial
                    }
                    else {
                        return self.isDimmed ? .regular: .prominent
                    }
                }() )
            }
            else {
                self.blurEffect = nil
            }

            if #available( iOS 13.0, * ) {
                self.blurEffectView.layer.cornerCurve = self.isCircular ? .circular: .continuous
            }
            self.blurEffectView.layer.cornerRadius = self.isCircular ? min( self.bounds.width, self.bounds.height ) / 2: self.rounding
            self.blurEffectView.layer.borderWidth = self.borderWidth
            self.blurEffectView.layer.borderColor = (!self.isDimmedBySelection || self.isDimmed ? self.borderColor: Theme.current.color.body.get())?.cgColor
            self.blurEffectView.alpha = self.isDimmed ? .long: .on
        }
    }
}
