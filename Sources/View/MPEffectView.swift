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

        defer {
            self.effectBackground = true
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }
}
