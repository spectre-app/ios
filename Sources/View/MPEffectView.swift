//
// Created by Maarten Billemont on 2019-10-12.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPEffectView: UIVisualEffectView {
    public var borderWidth         = CGFloat( 2 ) {
        didSet {
            self.updateBackground()
        }
    }
    public var isBackgroundVisible = true {
        didSet {
            self.updateBackground()
        }
    }
    public var isBackgroundDark    = false {
        didSet {
            self.updateBackground()
        }
    }
    public var isRound             = false {
        didSet {
            self.updateRounding()
        }
    }
    public var rounding            = CGFloat( 4 ) {
        didSet {
            self.updateRounding()
        }
    }
    public var isSelected          = false {
        didSet {
            self.updateContent()
        }
    }
    public var isDimmedBySelection = false {
        didSet {
            self.updateContent()
        }
    }

    init() {
        super.init( effect: nil )

        self.layer.masksToBounds = true

        self.contentView.layer.shadowRadius = 0
        self.contentView.layer.shadowOpacity = 0.382
        self.contentView.layer.shadowColor = appConfig.theme.color.shadow.get()?.cgColor
        self.contentView.layer.shadowOffset = CGSize( width: 0, height: 1 )

        self.updateBackground()
    }

    convenience init(content: UIView) {
        self.init()

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
            //self.tintColor = self.isBackgroundDark ? appConfig.theme.color.secondary.get(): appConfig.theme.color.backdrop.get()
            self.effect = self.isBackgroundVisible ? MPEffectView.effect( dark: self.isBackgroundDark ): nil
            self.layer.borderWidth = self.isBackgroundVisible ? self.borderWidth: 0
        }
    }

    func updateRounding() {
        DispatchQueue.main.perform {
            self.layer.cornerRadius = self.isRound ? self.bounds.size.height / 2: self.rounding
        }
    }

    func updateContent() {
        DispatchQueue.main.perform {
            self.layer.borderColor = appConfig.theme.color.body.get()?.cgColor

            if self.isDimmedBySelection && !self.isSelected {
                self.layer.borderColor = self.layer.borderColor?.copy( alpha: 0 )
                self.contentView.alpha = 0.618
            }
            else {
                self.contentView.alpha = 1
            }
        }
    }
}
