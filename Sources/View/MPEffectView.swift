//
// Created by Maarten Billemont on 2019-10-12.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPEffectView: UIVisualEffectView {
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
    public var isSelected          = true {
        didSet {
            self.updateDimming()
        }
    }
    public var isDimmedBySelection = false {
        didSet {
            self.updateDimming()
        }
    }

    init() {
        super.init( effect: nil )

        self.layer.borderWidth = 2
        self.layer.borderColor = MPTheme.global.color.body.get()?.cgColor
        self.layer.masksToBounds = true

        self.contentView.layer.shadowRadius = 0
        self.contentView.layer.shadowOpacity = 0.382
        self.contentView.layer.shadowColor = MPTheme.global.color.shadow.get()?.cgColor
        self.contentView.layer.shadowOffset = CGSize( width: 0, height: 1 )

        self.updateBackground()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override func layoutSubviews() {
        self.updateRounding()

        super.layoutSubviews()
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
            self.tintColor = self.isBackgroundDark ? MPTheme.global.color.secondary.get(): MPTheme.global.color.backdrop.get()
            self.effect = self.isBackgroundVisible ? MPEffectView.effect( dark: self.isBackgroundDark ): nil
        }
    }

    func updateRounding() {
        DispatchQueue.main.perform {
            self.layer.cornerRadius = self.isRound ? self.bounds.size.height / 2: self.rounding
        }
    }

    func updateDimming() {
        DispatchQueue.main.perform {
            if self.isDimmedBySelection && !self.isSelected {
                self.layer.borderColor = self.layer.borderColor?.copy( alpha: 0 )
                self.contentView.alpha = 0.618
            }
            else {
                self.layer.borderColor = self.layer.borderColor?.copy( alpha: 1 )
                self.contentView.alpha = 1
            }
        }
    }
}
