//
// Created by Maarten Billemont on 2018-03-04.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class MPSpinnerView: UIView {

    private lazy var panRecognizer = UIPanGestureRecognizer( target: self, action: #selector( didPan(recognizer:) ) )

    var items:        Int {
        get {
            return self.subviews.count
        }
    }
    var selectedItem: Int? {
        didSet {
            self.scannedItem = CGFloat( self.selectedItem ?? 0 )
        }
    }
    var scannedItem:  CGFloat = 0 {
        didSet {
            self.setNeedsLayout()
        }
    }

    override init(frame: CGRect) {
        super.init( frame: frame )

        self.addGestureRecognizer( self.panRecognizer )
        self.isUserInteractionEnabled = true
    }

    required init?(coder aDecoder: NSCoder) {
        super.init( coder: aDecoder )
    }

    override func didAddSubview(_ subview: UIView) {
        super.didAddSubview( subview )

        self.panRecognizer.isEnabled = self.items > 0
    }

    override func willRemoveSubview(_ subview: UIView) {
        super.willRemoveSubview( subview )

        self.panRecognizer.isEnabled = self.items > 0
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        for s in 0..<self.subviews.count {
            let subview = self.subviews[s]
            subview.sizeToFit()

            let itemDistance = 50 * (CGFloat( s ) - self.scannedItem)
            subview.center = CGPoint( x: self.center.x, y: self.center.y + itemDistance )
        }
    }

    @objc func didPan(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
            case .possible:
                ()

            case .began, .changed:
                guard self.items > 0 else {
                    return
                }

                let itemDistance = self.bounds.height / CGFloat( self.items )
                self.scannedItem = CGFloat( self.selectedItem ?? 0 ) + recognizer.translation( in: self ).y / itemDistance

            case .ended:
                self.selectedItem = Int( self.scannedItem.rounded( .toNearestOrAwayFromZero ) )

            case .cancelled, .failed:
                self.scannedItem = CGFloat( self.selectedItem ?? 0 )
        }
    }
}
