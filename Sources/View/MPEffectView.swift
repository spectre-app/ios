//
// Created by Maarten Billemont on 2019-10-12.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPEffectView: UIVisualEffectView {
    public var borderWidth : CGFloat {
        didSet {
            self.updateBackground()
        }
    }
    public var isBackground:        Bool {
        didSet {
            self.updateBackground()
        }
    }
    public var isDark:              Bool {
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
    public var isSelected  = false {
        didSet {
            self.updateContent()
        }
    }

    init(border: CGFloat = 2, background: Bool = true, dark: Bool = false, round: Bool = false, rounding: CGFloat = 4, dims: Bool = false) {
        self.borderWidth = border
        self.isBackground = background
        self.isDark = dark
        self.isRound = round
        self.rounding = rounding
        self.isDimmedBySelection = dims
        super.init( effect: nil )

        self.layer.masksToBounds = true

        self.contentView.layer.shadowRadius = 0
        self.contentView.layer.shadowOpacity = .short
        self.contentView.layer => \.shadowColor => Theme.current.color.shadow
        self.contentView.layer.shadowOffset = CGSize( width: 0, height: 1 )

        self.updateBackground()
    }

    convenience init(content: UIView, border: CGFloat = 2, background: Bool = true, dark: Bool = false, round: Bool = false, rounding: CGFloat = 4, dims: Bool = false) {
        self.init( border: border, background: background, dark: dark, round: round, rounding: rounding, dims: false )

        // - View
        self.contentView.addSubview( content )

        // - Layout
        LayoutConfiguration( view: content )
                .constrain( margins: true )
                .activate()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
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

    private static func effect(dark: Bool) -> UIVisualEffect {
        if #available( iOS 13, * ) {
            return UIBlurEffect( style: dark ? .systemUltraThinMaterialDark: .systemUltraThinMaterialLight )
        }
        else {
            return UIBlurEffect( style: dark ? .dark: .light )
        }
    }

    func updateBackground() {
        DispatchQueue.main.perform {
            //self.tintColor = self.isBackgroundDark ? MPTheme.current.color.secondary.get(): MPTheme.current.color.backdrop.get()
            self.effect = self.isBackground ? MPEffectView.effect( dark: self.isDark ): nil
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
            self.layer => \.borderColor => Theme.current.color.body

            if self.isDimmedBySelection && !self.isSelected {
                self.layer.borderColor = self.layer.borderColor?.copy( alpha: 0 )
                self.contentView.alpha = .long
            }
            else {
                self.contentView.alpha = 1
            }
        }
    }
}
