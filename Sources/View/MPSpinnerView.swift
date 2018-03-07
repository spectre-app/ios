//
// Created by Maarten Billemont on 2018-03-04.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit
import pop

protocol MPSpinnerDelegate {
    func spinner(_ spinner: MPSpinnerView, didScanItem scannedItem: CGFloat)
    func spinner(_ spinner: MPSpinnerView, didSelectItem selectedItem: Int?)
}

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

    private var startedItem: CGFloat = 0
    private var scannedItem: CGFloat = 0 {
        didSet {
            self.setNeedsLayout()
            if let delegate = self.delegate {
                delegate.spinner( self, didScanItem: self.scannedItem )
            }
        }
    }

    public var delegate:     MPSpinnerDelegate?
    public var selectedItem: Int? {
        didSet {
            self.scan( toItem: CGFloat( self.selectedItem ?? 0 ) )
            if let delegate = self.delegate {
                delegate.spinner( self, didSelectItem: self.selectedItem )
            }
        }
    }
    public var items:        Int {
        get {
            return self.subviews.count
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

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        var fittingSize = CGSize( width: 0, height: 0 )
        for subview in self.subviews {
            fittingSize = CGSizeUnion( fittingSize, subview.sizeThatFits( size ) )
        }

        fittingSize.height *= 3
        return fittingSize
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let center = CGRectGetCenter( self.bounds )
        for s in 0..<self.subviews.count {
            let subview = self.subviews[s]
            subview.sizeToFit()

            let ds = CGFloat( s ) - self.scannedItem
            if ds > 0 {
                // subview shows before scanned item.
                subview.center = CGPoint( x: center.x, y: center.y - 100 * pow( ds, 2 ) )
                subview.alpha = max( 0, 1 - pow( ds, 2 ) )
                let scale = pow( ds * 0.2 + 1, 2 )
                subview.transform = CGAffineTransform.init( scaleX: scale, y: scale )
            }
            else {
                // subview shows behind scanned item.
                subview.center = CGPoint( x: center.x, y: center.y + 100 * pow( ds * 0.5, 2 ) )
                subview.alpha = max( 0, 1 - pow( ds * 0.8, 2 ) )
                let scale = 1 / pow( ds * 0.2 - 1, 2 )
                subview.transform = CGAffineTransform.init( scaleX: scale, y: scale )
            }
        }
    }

    public func scan(toItem item: CGFloat, animated: Bool = true) {
        guard self.scannedItem != item else {
            return
        }

        if animated {
            let anim = POPSpringAnimation()
            anim.property = self.pop_scannedItem
            anim.toValue = item
            self.pop_removeAnimation( forKey: anim.property.name )
            self.pop_add( anim, forKey: anim.property.name )
        }
        else {
            self.pop_removeAnimation( forKey: self.pop_scannedItem.name )
            self.scannedItem = item
        }
    }

    @objc private func didPan(recognizer: UIPanGestureRecognizer) {
        guard self.items > 0 else {
            return
        }
        let itemDistance = (self.bounds.height * 2 / 3) / CGFloat( self.items )

        switch recognizer.state {
            case .possible:
                ()

            case .began:
                self.startedItem = self.scannedItem

            case .changed:
                // While panning, update scannedItem relative to startedItem.
                self.scan( toItem: self.startedItem + recognizer.translation( in: self ).y / itemDistance, animated: false )

            case .ended:
                let anim = POPDecayAnimation()
                anim.property = self.pop_scannedItem
                anim.velocity = recognizer.velocity( in: self ).y / itemDistance

                // Enforce a limit on scannedItem when ending/decaying.
                anim.animationDidApplyBlock = { animation in
                    if self.scannedItem < 0 || self.scannedItem > CGFloat( self.items - 1 ) {
                        let anim = POPSpringAnimation()
                        anim.property = self.pop_scannedItem
                        anim.velocity = (animation as? POPDecayAnimation)?.velocity ?? 0
                        anim.toValue = max( 0, min( self.items - 1, Int( self.scannedItem ) ) )
                        anim.completionBlock = animation?.completionBlock
                        self.pop_removeAnimation( forKey: anim.property.name )
                        self.pop_add( anim, forKey: anim.property.name )
                    }
                }

                // After decaying, select the item we land on.
                anim.completionBlock = { animation, finished in
                    if finished {
                        self.selectedItem = max( 0, min( self.items - 1, Int( self.scannedItem.rounded( .toNearestOrAwayFromZero ) ) ) )
                    }
                }

                self.pop_removeAnimation( forKey: anim.property.name )
                self.pop_add( anim, forKey: anim.property.name )

            case .cancelled, .failed:
                // Abort by resetting to the selected item.
                self.scan( toItem: CGFloat( self.selectedItem ?? 0 ) )
        }
    }
}
