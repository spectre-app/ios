//
// Created by Maarten Billemont on 2019-10-12.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPEffectView: UIView {
    public var borderWidth:         CGFloat {
        didSet {
            self.updateBackground()
        }
    }
    public var isBackground:        Bool {
        didSet {
            self.updateBackground()
        }
    }
    public var isRound:             Bool {
        didSet {
            self.updateRounding()
        }
    }
    public var rounding:            CGFloat {
        didSet {
            self.updateRounding()
        }
    }
    public var isDimmedBySelection: Bool {
        didSet {
            self.updateContent()
        }
    }
    public var isSelected = false {
        didSet {
            self.updateContent()
        }
    }

    override var layoutMargins: UIEdgeInsets {
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

        self.updateBackground()

        self.blurEffectView.contentView.addSubview( self.vibrancyEffectView )
        self.addSubview( self.blurEffectView )

        LayoutConfiguration( view: self.vibrancyEffectView ).constrain().activate()
        LayoutConfiguration( view: self.blurEffectView ).constrain().activate()
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

    override func layoutSubviews() {
        self.updateRounding()

        super.layoutSubviews()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange( previousTraitCollection )

        self.updateContent()
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()

        self.updateContent()
    }

    // MARK: Private

    func updateBackground() {
        DispatchQueue.main.perform {
            //self.tintColor = self.isBackgroundDark ? MPTheme.current.color.secondary.get(): MPTheme.current.color.backdrop.get()
            if self.isBackground {
                if #available( iOS 13, * ) {
                    self.blurEffect = UIBlurEffect( style: .systemUltraThinMaterial )
                }
                else {
                    self.blurEffect = UIBlurEffect( style: .prominent )
                }
            }
            else {
                self.blurEffect = nil
            }
            self.layer.borderWidth = self.isBackground ? self.borderWidth: 0
        }
    }

    func updateRounding() {
        DispatchQueue.main.perform {
            self.layer.cornerRadius = self.isRound ? self.bounds.size.height / 2: self.rounding
        }
    }

    func updateContent() {
        DispatchQueue.main.perform {
            self.layer => \.borderColor => Theme.current.color.secondary

            if self.isDimmedBySelection && !self.isSelected {
                self.layer.borderColor = self.layer.borderColor?.copy( alpha: 0 )
                self.alpha = .long
            }
            else {
                self.alpha = 1
            }
        }
    }
}
