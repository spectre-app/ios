//
// Created by Maarten Billemont on 2019-10-12.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPEffectView: UIVisualEffectView {
    public var effectBackground = false {
        didSet {
            DispatchQueue.main.perform {
                if self.effectBackground {
                    self.effect = MPEffectView.effect( dark: self.darkBackground )
                }
                else {
                    self.effect = nil
                }
            }
        }
    }
    public var darkBackground = false {
        didSet {
            DispatchQueue.main.perform {
                self.tintColor = self.darkBackground ? MPTheme.global.color.secondary.get(): MPTheme.global.color.backdrop.get()
                self.effectBackground = { self.effectBackground }()
            }
        }
    }
    public var round    = false {
        didSet {
            self.setNeedsUpdateConstraints()
        }
    }
    public var rounding = CGFloat( 4 ) {
        didSet {
            self.setNeedsUpdateConstraints()
        }
    }

    public var isSelected            = false {
        didSet {
            if self.isBorderedOnSelection && !self.isSelected {
                self.layer.borderColor = self.layer.borderColor?.copy( alpha: 0 )
            }
            else {
                self.layer.borderColor = self.layer.borderColor?.copy( alpha: 1 )
            }
        }
    }
    public var isBorderedOnSelection = false

    public static func effect(dark: Bool) -> UIVisualEffect {
        if #available( iOS 13, * ) {
            return UIBlurEffect( style: dark ? .systemUltraThinMaterialDark: .systemUltraThinMaterialLight )
        }
        else {
            return UIBlurEffect( style: dark ? .dark: .light )
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
        if #available( iOS 11.0, * ) {
            self.contentView.insetsLayoutMarginsFromSafeArea = false
        }


        defer {
            self.effectBackground = true
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override func layoutSubviews() {
        self.layer.cornerRadius = self.round ? self.bounds.size.height / 2: self.rounding

        super.layoutSubviews()
    }
}
