//
// Created by Maarten Billemont on 2018-03-04.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit
import pop

protocol MPSpinnerDelegate {
    func spinner(_ spinner: MPSpinnerView, didScanItem scannedItem: CGFloat)
    func spinner(_ spinner: MPSpinnerView, didSelectItem selectedItem: Int?)
    func spinner(_ spinner: MPSpinnerView, didActivateItem activatedItem: Int)
    func spinner(_ spinner: MPSpinnerView, didDeactivateItem deactivatedItem: Int)
}

class MPSpinnerView: UIView {
    public var delegate:      MPSpinnerDelegate?
    public var selectedItem:  Int? {
        didSet {
            DispatchQueue.main.perform {
                if let selectedItem = self.selectedItem {
                    self.scan( toItem: CGFloat( selectedItem ) )
                }
                if let delegate = self.delegate {
                    delegate.spinner( self, didSelectItem: self.selectedItem )
                    self.setNeedsLayout()
                }
            }
        }
    }
    public var activatedItem: Int? {
        willSet {
            DispatchQueue.main.perform {
                if let delegate = self.delegate,
                   let activatedItem = self.activatedItem, activatedItem != newValue {
                    delegate.spinner( self, didDeactivateItem: activatedItem )
                }
            }
        }
        didSet {
            self.selectedItem = self.activatedItem

            DispatchQueue.main.perform {
                if let delegate = self.delegate,
                   let activatedItem = self.activatedItem {
                    delegate.spinner( self, didActivateItem: activatedItem )
                    self.setNeedsLayout()
                }
            }
        }
    }
    public var items:         Int {
        get {
            return self.subviews.count
        }
    }

    private lazy var panRecognizer = UIPanGestureRecognizer( target: self, action: #selector( didPan(recognizer:) ) )
    private lazy var tapRecognizer = UITapGestureRecognizer( target: self, action: #selector( didTap(recognizer:) ) )
    private var startedItem: CGFloat = 0
    @objc
    private var scannedItem: CGFloat = 0 {
        didSet {
            DispatchQueue.main.perform {
                if let delegate = self.delegate {
                    delegate.spinner( self, didScanItem: self.scannedItem )
                }

                self.setNeedsLayout()
            }
        }
    }

    // MARK: --- Life ---

    override init(frame: CGRect) {
        super.init( frame: frame )

        self.addGestureRecognizer( self.panRecognizer )
        self.addGestureRecognizer( self.tapRecognizer )

        self.autoresizesSubviews = false
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

    override func updateConstraints() {
        super.updateConstraints()

        for subview in self.subviews {
            if subview.tag != 1 {
                subview.tag = 1
                subview.translatesAutoresizingMaskIntoConstraints = false
                subview.topAnchor.constraint( greaterThanOrEqualTo: self.topAnchor ).activate()
                subview.leadingAnchor.constraint( greaterThanOrEqualTo: self.leadingAnchor ).activate()
                subview.trailingAnchor.constraint( lessThanOrEqualTo: self.trailingAnchor ).activate()
                subview.bottomAnchor.constraint( lessThanOrEqualTo: self.bottomAnchor ).activate()
                subview.centerXAnchor.constraint( equalTo: self.centerXAnchor ).activate()
                subview.centerYAnchor.constraint( equalTo: self.centerYAnchor ).activate()
                subview.widthAnchor.constraint( equalToConstant: 0 ).withPriority( .fittingSizeLevel ).activate()
                subview.heightAnchor.constraint( equalToConstant: 0 ).withPriority( .fittingSizeLevel ).activate()
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        for s in 0..<self.subviews.count {
            let subview = self.subviews[s] as UIView

            let ds = CGFloat( s ) - self.scannedItem
            if ds > 0 {
                // subview shows before scanned item.
                let scale = pow( ds * 0.2 + 1, 2 )
                subview.transform = CGAffineTransform.identity
                        .translatedBy( x: 0, y: -100 * pow( ds, 2 ) )
                        .scaledBy( x: scale, y: scale )
                subview.alpha = max( 0, 1 - pow( ds, 2 ) )
            }
            else {
                // subview shows behind scanned item.
                let scale = 1 / pow( ds * 0.2 - 1, 2 )
                subview.transform = CGAffineTransform.identity
                        .translatedBy( x: 0, y: 100 * pow( ds * 0.5, 2 ) )
                        .scaledBy( x: scale, y: scale )
                subview.alpha = max( 0, 1 - pow( ds * 0.8, 2 ) )
            }
        }
    }

    // MARK: --- Interface ---

    public func scan(toItem item: CGFloat, animated: Bool = true) {
        guard self.scannedItem != item
        else {
            return
        }

        if animated {
            let anim = POPSpringAnimation( floatAtKeyPath: "scannedItem", on: MPSpinnerView.self )
            anim.toValue = item
            self.pop_removeAnimation( forKey: "pop.scannedItem" )
            self.pop_add( anim, forKey: "pop.scannedItem" )
        }
        else {
            self.pop_removeAnimation( forKey: "pop.scannedItem" )
            self.scannedItem = item
        }
    }

    // MARK: --- Private ---

    @objc private func didPan(recognizer: UIPanGestureRecognizer) {
        guard self.items > 0
        else {
            return
        }
        let itemDistance = (self.bounds.height * 2 / 3) / CGFloat( self.items )

        switch recognizer.state {
            case .possible:
                ()

            case .began:
                self.startedItem = self.scannedItem
                self.activatedItem = nil

            case .changed:
                // While panning, update scannedItem relative to startedItem.
                self.scan( toItem: self.startedItem + recognizer.translation( in: self ).y / itemDistance, animated: false )

            case .ended:
                let anim = POPDecayAnimation( floatAtKeyPath: "scannedItem", on: MPSpinnerView.self )
                anim.velocity = recognizer.velocity( in: self ).y / itemDistance

                // Enforce a limit on scannedItem when ending/decaying.
                anim.animationDidApplyBlock = { animation in
                    if self.scannedItem < 0 || self.scannedItem > CGFloat( self.items - 1 ) {
                        let anim = POPSpringAnimation( floatAtKeyPath: "scannedItem", on: MPSpinnerView.self )
                        anim.velocity = (animation as? POPDecayAnimation)?.velocity ?? 0
                        anim.toValue = max( 0, min( self.items - 1, Int( self.scannedItem ) ) )
                        anim.completionBlock = animation?.completionBlock
                        self.pop_removeAnimation( forKey: "pop.scannedItem" )
                        self.pop_add( anim, forKey: "pop.scannedItem" )
                    }
                }

                // After decaying, select the item we land on.
                anim.completionBlock = { animation, finished in
                    if finished {
                        self.selectedItem = self.findScannedItem()
                    }
                }

                self.pop_removeAnimation( forKey: "pop.scannedItem" )
                self.pop_add( anim, forKey: "pop.scannedItem" )

            case .cancelled, .failed:
                // Abort by resetting to the selected item.
                self.scan( toItem: CGFloat( self.selectedItem ?? 0 ) )
        }
    }

    @objc private func didTap(recognizer: UITapGestureRecognizer) {
        switch recognizer.state {

            case .possible, .began, .changed, .cancelled, .failed:
                ()

            case .ended:
                let scannedItem = self.findScannedItem()
                self.activatedItem = self.activatedItem == scannedItem ? nil : scannedItem
        }
    }

    private func findScannedItem() -> Int {
        return max( 0, min( self.items - 1, Int( self.scannedItem.rounded( .toNearestOrAwayFromZero ) ) ) )
    }
}
