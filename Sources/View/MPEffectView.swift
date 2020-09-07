//
// Created by Maarten Billemont on 2019-10-12.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPEffectView: UIView {
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
    public var   isRound:             Bool {
        didSet {
            if self.isRound != oldValue {
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
    override var bounds:              CGRect {
        didSet {
            if self.isRound && self.bounds != oldValue {
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

    init(border: CGFloat = 2, background: Bool = true, round: Bool = false, rounding: CGFloat = 4, dims: Bool = false) {
        self.borderWidth = border
        self.isBackground = background
        self.isRound = round
        self.rounding = rounding
        self.isDimmedBySelection = dims

        super.init( frame: .zero )

        self.layer.masksToBounds = true
        self.layer.shadowRadius = 0
        self.layer.shadowOpacity = .short
        self.layer => \.shadowColor => Theme.current.color.shadow
        self.layer.shadowOffset = CGSize( width: 0, height: 1 )

        self => \.borderColor => Theme.current.color.secondary

        self.blurEffectView.contentView.addSubview( self.vibrancyEffectView )
        self.addSubview( self.blurEffectView )

        LayoutConfiguration( view: self.vibrancyEffectView ).constrain().activate()
        LayoutConfiguration( view: self.blurEffectView ).constrain().activate()

        self.update()
    }

    convenience init(content: UIView, border: CGFloat = 2, background: Bool = true, round: Bool = false, rounding: CGFloat = 4, dims: Bool = false) {
        self.init( border: border, background: background, round: round, rounding: rounding, dims: false )

        // - View
        self.addSubview( content )

        // - Layout
        LayoutConfiguration( view: content )
                .constrain( margins: true )
                .activate()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override func addSubview(_ view: UIView) {
        if view == self.blurEffectView {
            super.addSubview( view )
        }
        else {
            self.vibrancyEffectView.contentView.addSubview( view )
        }
    }

    // MARK: --- Updatable ---

    private func update() {
        DispatchQueue.main.perform {
            self.layer.cornerRadius = self.isRound ? self.bounds.size.height / 2: self.rounding

            if self.isBackground {
                self.layer.borderWidth = self.borderWidth
                if #available( iOS 13, * ) {
                    self.blurEffect = UIBlurEffect( style: .systemUltraThinMaterial )
                }
                else {
                    self.blurEffect = UIBlurEffect( style: .prominent )
                }
            }
            else {
                self.layer.borderWidth = 0
                self.blurEffect = nil
            }

            self.layer.borderColor = self.borderColor?.cgColor
            if self.isDimmedBySelection && !self.isSelected {
                self.alpha = .short
            }
            else {
                self.alpha = 1
            }
        }
    }
}
