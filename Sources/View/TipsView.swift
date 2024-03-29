// =============================================================================
// Created by Maarten Billemont on 2021-03-06.
// Copyright (c) 2021 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import UIKit

class TipsView: BaseView {
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

    // MARK: - Life

    public required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(tips: [Text], first: Int? = nil, random: Bool = false, duration: TimeInterval = 10) {
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

    // MARK: - Interface

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

            UIView.animate( withDuration: .short, animations: {
                self.tipLabel.alpha = .off
            }, completion: { _ in
                self.tipLabel.applyText( tip ?? "" )

                UIView.animate( withDuration: .short, animations: {
                    self.tipLabel.alpha = .on
                } )
            } )

            self.tipExpiryConfiguration.deactivate( animationDuration: 0 )
            self.tipExpiryConfiguration.activate( animationDuration: self.duration )
            DispatchQueue.main.perform( deadline: .now() + .seconds( self.duration ) ) { [weak self] in self?.cycle() }
        }
    }
}
