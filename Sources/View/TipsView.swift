//
// Created by Maarten Billemont on 2021-03-06.
// Copyright (c) 2021 Lyndir. All rights reserved.
//

import UIKit

class TipsView: UIView {
    private let tipLabel    = UILabel()
    private let tipProgress = UIView()
    private var tipExpiryConfiguration: LayoutConfiguration<UIView>!

    var tips:     [Text] {
        didSet {
            self.cycle()
        }
    }
    var currentTip = 0
    var nextTip:  Int?
    var random:   Bool
    var duration: TimeInterval

    // MARK: --- Life ---

    public required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(tips: [Text], first: Int? = nil, random: Bool = true, duration: TimeInterval = 10) {
        self.tips = tips
        self.nextTip = first
        self.random = random
        self.duration = duration
        super.init( frame: .zero )

        // - View
        self.tipProgress => \.backgroundColor => Theme.current.color.secondary
        self.tipLabel => \.textColor => Theme.current.color.secondary
        self.tipLabel => \.font => Theme.current.font.caption2
        self.tipLabel.textAlignment = .center
        self.tipLabel.numberOfLines = 0

        // - Hierarchy
        self.addSubview( self.tipLabel )
        self.addSubview( self.tipProgress )

        // - Layout
        LayoutConfiguration( view: self.tipLabel )
                .constrain( as: .verticalCenterH )
                .activate()
        LayoutConfiguration( view: self.tipProgress )
                .constrain( as: .bottomCenter )
                .constrain { $1.heightAnchor.constraint( equalToConstant: 1 ) }
                .activate()
        self.tipExpiryConfiguration = LayoutConfiguration( view: self.tipProgress ) { active, inactive in
            inactive.constrain { $1.widthAnchor.constraint( equalToConstant: 20 ) }
            active.constrain { $1.widthAnchor.constraint( equalToConstant: 0 ) }
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if self.window != nil {
            self.cycle()
        }
    }

    // MARK: --- Interface ---

    func cycle() {
        DispatchQueue.main.perform {
            guard self.window != nil
            else { return }

            var tip: Text?
            if let nextTip = self.nextTip {
                tip = self.tips[nextTip]
                self.nextTip = nil
            }
            else if self.random {
                tip = self.tips.randomElement()
                while self.tips.count > 1 && tip?.description == self.tipLabel.text {
                    tip = self.tips.randomElement() ?? ""
                }
            }
            else {
                self.currentTip = (self.currentTip + 1) % self.tips.count
                tip = self.tips[self.currentTip]
            }

            let attributedTip = NSMutableAttributedString( attributedString: (tip ?? "").attributedString )
            attributedTip.enumerateAttributes( in: NSRange( location: 0, length: attributedTip.length ) ) { attributes, range, stop in
                var fixedAttributes = attributes, fixed = false
                if let font = attributes[.font] as? UIFont, font.pointSize != self.tipLabel.font.pointSize {
                    fixedAttributes[.font] = font.withSize( self.tipLabel.font.pointSize )
                    fixed = true
                }
                if let color = attributes[.foregroundColor] as? UIColor, color != self.tipLabel.textColor.with( alpha: color.alpha ) {
                    fixedAttributes[.foregroundColor] = self.tipLabel.textColor.with( alpha: color.alpha )
                    fixed = true
                }
                if fixed {
                    attributedTip.setAttributes( fixedAttributes, range: range )
                }
            }

            UIView.animate( withDuration: .long, animations: {
                self.tipLabel.alpha = .off
            }, completion: { _ in
                self.tipLabel.attributedText = attributedTip

                UIView.animate( withDuration: .short, animations: {
                    self.tipLabel.alpha = .on
                } )
            } )

            self.tipExpiryConfiguration.deactivate( animationDuration: 0 )
            self.tipExpiryConfiguration.activate( animationDuration: self.duration )
            DispatchQueue.main.perform( deadline: .now() + .seconds( self.duration ) ) { self.cycle() }
        }
    }
}
