//
// Created by Maarten Billemont on 2018-03-04.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit
import pop

class MPSpinnerView: UIView {

    private lazy var panRecognizer = UIPanGestureRecognizer( target: self, action: #selector( didPan(recognizer:) ) )
    private let pop_scannedItem = POPAnimatableProperty.property( withName: "MPSpinnerView.scannedItem", initializer: { prop in
        prop!.readBlock = { obj, floats in
            floats![0] = (obj as! MPSpinnerView).scannedItem
        }
        prop!.writeBlock = { obj, floats in
            (obj as! MPSpinnerView).scannedItem = floats![0]
        }
        prop!.threshold = 0.01
    } ) as! POPAnimatableProperty

    var items:        Int {
        get {
            return self.subviews.count
        }
    }
    var selectedItem: Int? {
        didSet {
            let anim = POPSpringAnimation()
            anim.property = pop_scannedItem
            anim.toValue = (self.selectedItem ?? 0)
            self.pop_add( anim, forKey: pop_scannedItem.name )
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
        fatalError( "init(coder:) is not supported for this class" )
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

            let ds = CGFloat( s ) - self.scannedItem
            if ds < 0 {
                subview.center = CGPoint( x: self.center.x, y: self.center.y + 20 * sqrt( -ds / CGFloat( self.items ) ) )
                subview.alpha = 1
                let scale = 1 - pow( -ds / CGFloat( self.items ), 2 ) / 2
                subview.transform = CGAffineTransform.init( scaleX: scale, y: scale )
            } else {
                subview.center = CGPoint( x: self.center.x, y: self.center.y - 100 * sqrt( ds / CGFloat( self.items ) ) )
                subview.alpha = 1 - min( 0.8, ds ) / 0.8
                let scale = 1 + pow( ds / CGFloat( self.items ), 2 ) * 2
                subview.transform = CGAffineTransform.init(scaleX: scale, y: scale)
            }
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

                let itemDistance = (self.bounds.height * 2 / 3) / CGFloat( self.items )
                self.scannedItem = CGFloat( self.selectedItem ?? 0 ) + recognizer.translation( in: self ).y / itemDistance

            case .ended:
                self.selectedItem = max( 0, min( self.items - 1, Int( self.scannedItem.rounded( .toNearestOrAwayFromZero ) ) ) )

            case .cancelled, .failed:
                self.scannedItem = CGFloat( self.selectedItem ?? 0 )
        }
    }
}
