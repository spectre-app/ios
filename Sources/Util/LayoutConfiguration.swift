//
// Created by Maarten Billemont on 2019-11-09.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

struct Anchor: OptionSet {
    let rawValue: UInt

    static let leading        = Anchor( rawValue: 1 << 0 )
    static let trailing       = Anchor( rawValue: 1 << 1 )
    static let left           = Anchor( rawValue: 1 << 2 )
    static let right          = Anchor( rawValue: 1 << 3 )
    static let top            = Anchor( rawValue: 1 << 4 )
    static let bottom         = Anchor( rawValue: 1 << 5 )
    static let width          = Anchor( rawValue: 1 << 6 )
    static let height         = Anchor( rawValue: 1 << 7 )
    static let centerX        = Anchor( rawValue: 1 << 8 )
    static let centerY        = Anchor( rawValue: 1 << 9 )
    static let center         = Anchor( arrayLiteral: Anchor.centerX, Anchor.centerY )
    static let horizontally   = Anchor( arrayLiteral: Anchor.leading, Anchor.trailing )
    static let vertically     = Anchor( arrayLiteral: Anchor.top, Anchor.bottom )
    static let box            = Anchor( arrayLiteral: Anchor.horizontally, Anchor.vertically )
    static let leadingBox     = Anchor( arrayLiteral: Anchor.leading, Anchor.vertically )
    static let leadingCenter  = Anchor( arrayLiteral: Anchor.leading, Anchor.centerY )
    static let trailingBox    = Anchor( arrayLiteral: Anchor.trailing, Anchor.vertically )
    static let trailingCenter = Anchor( arrayLiteral: Anchor.trailing, Anchor.centerY )
    static let topBox         = Anchor( arrayLiteral: Anchor.top, Anchor.horizontally )
    static let topCenter      = Anchor( arrayLiteral: Anchor.top, Anchor.centerX )
    static let bottomBox      = Anchor( arrayLiteral: Anchor.bottom, Anchor.horizontally )
    static let bottomCenter   = Anchor( arrayLiteral: Anchor.bottom, Anchor.centerX )
}

public struct LayoutTarget: CustomStringConvertible {
    public let view:                UIView?
    public let layoutGuide:         UILayoutGuide?
    public var description:         String {
        describe( self.view ) ?? self.layoutGuide?.description ?? "-"
    }
    public var owningView:          UIView? {
        self.view?.superview ?? self.layoutGuide?.owningView
    }
    public var leadingAnchor:       NSLayoutXAxisAnchor! {
        self.view?.leadingAnchor ?? self.layoutGuide?.leadingAnchor
    }
    public var trailingAnchor:      NSLayoutXAxisAnchor! {
        self.view?.trailingAnchor ?? self.layoutGuide?.trailingAnchor
    }
    public var leftAnchor:          NSLayoutXAxisAnchor! {
        self.view?.leftAnchor ?? self.layoutGuide?.leftAnchor
    }
    public var rightAnchor:         NSLayoutXAxisAnchor! {
        self.view?.rightAnchor ?? self.layoutGuide?.rightAnchor
    }
    public var topAnchor:           NSLayoutYAxisAnchor! {
        self.view?.topAnchor ?? self.layoutGuide?.topAnchor
    }
    public var bottomAnchor:        NSLayoutYAxisAnchor! {
        self.view?.bottomAnchor ?? self.layoutGuide?.bottomAnchor
    }
    public var widthAnchor:         NSLayoutDimension! {
        self.view?.widthAnchor ?? self.layoutGuide?.widthAnchor
    }
    public var heightAnchor:        NSLayoutDimension! {
        self.view?.heightAnchor ?? self.layoutGuide?.heightAnchor
    }
    public var centerXAnchor:       NSLayoutXAxisAnchor! {
        self.view?.centerXAnchor ?? self.layoutGuide?.centerXAnchor
    }
    public var centerYAnchor:       NSLayoutYAxisAnchor! {
        self.view?.centerYAnchor ?? self.layoutGuide?.centerYAnchor
    }
    public var firstBaselineAnchor: NSLayoutYAxisAnchor? {
        self.view?.firstBaselineAnchor
    }
    public var lastBaselineAnchor:  NSLayoutYAxisAnchor? {
        self.view?.lastBaselineAnchor
    }
}

/**
 * A layout configuration holds a set of operations that will be performed on the target when the configuration's active state changes.
 */
public class LayoutConfiguration: CustomStringConvertible, ThemeObserver {

    //! The target upon which this configuration's operations operate.
    public let  target:    LayoutTarget
    //! Whether this configuration has last been activated or deactivated.
    private var activation             = false
    public var  activated: Bool {
        get {
            self.activation
        }
        set {
            if newValue != self.activated {
                if newValue {
                    self.activate()
                }
                else {
                    self.deactivate()
                }
            }
        }
    }
    //! Child configurations which will be activated when this configuration is activated and deactivated when this configuration is deactivated.
    public var  activeConfigurations   = [ LayoutConfiguration ]()
    //! Child configurations which will be deactivated when this configuration is activated and activated when this configuration is deactivated.
    public var  inactiveConfigurations = [ LayoutConfiguration ]()

    private var constrainers       = [ (UIView, LayoutTarget) -> [NSLayoutConstraint] ]()
    private var activeConstraints  = Set<NSLayoutConstraint>()
    private var layoutViews        = [ WeakBox<UIView> ]()
    private var displayViews       = [ WeakBox<UIView> ]()
    private var actions            = [ (UIView) -> Void ]()
    private var activeValues       = [ String: () -> Any? ]()
    private var inactiveValues     = [ String: Any? ]()
    private var activeProperties   = [ String: Any ]()
    private var inactiveProperties = [ String: Any ]()

    public var description: String {
        var description = "\(self.target)[\(self.activation ? "on": "off")]: "
        if !self.constrainers.isEmpty || !self.activeConstraints.isEmpty {
            description += "constrainers:\(self.constrainers.count), "
        }
        if !self.activeValues.isEmpty {
            description += "keys:\(self.activeValues.keys), "
        }
        if !self.activeConfigurations.isEmpty || !self.inactiveConfigurations.isEmpty {
            description += "children:active[\(self.activeConfigurations.count)],inactive[\(self.inactiveConfigurations.count)]"
        }
        return description
    }

    //! Create a new configuration for the view and automatically add an active and inactive child configuration for it configure them in the block.  New configurations start deactivated and the inactive configuration starts activated.
    public convenience init(view: UIView? = nil, configurations: ((LayoutConfiguration, LayoutConfiguration) -> Void)? = nil) {
        self.init( target: LayoutTarget( view: view, layoutGuide: nil ), configurations: configurations )
    }

    //! Create a new configuration for a layout guide created in the view and automatically add an active and inactive child configuration for it configure them in the block.  New configurations start deactivated and the inactive configuration starts activated.
    public convenience init(layoutGuide: UILayoutGuide, configurations: ((LayoutConfiguration, LayoutConfiguration) -> Void)? = nil) {
        self.init( target: LayoutTarget( view: nil, layoutGuide: layoutGuide ), configurations: configurations )
    }

    private init(target: LayoutTarget, configurations: ((LayoutConfiguration, LayoutConfiguration) -> Void)? = nil) {
        self.target = target
        if let configurations = configurations {
            self.apply( configurations )
        }
        self.deactivate()
    }

    //! Add child configurations that triggers when this configuration's activation changes.
    @discardableResult func apply(_ configurations: (LayoutConfiguration, LayoutConfiguration) -> Void) -> Self {
        let active   = LayoutConfiguration( target: self.target )
        let inactive = LayoutConfiguration( target: self.target )
        configurations( active, inactive )
        self.apply( active, active: true )
        self.apply( inactive, active: false )

        return self
    }

    //! Add a child configuration that triggers when this configuration is activated or deactivated.
    @discardableResult func apply(_ configuration: LayoutConfiguration, active: Bool = true) -> Self {
        if active {
            self.activeConfigurations.append( configuration )
            configuration.activated = self.activation
        }
        else {
            self.inactiveConfigurations.append( configuration )
            configuration.activated = !self.activation
        }

        return self
    }

/** Activate this constraint when the configuration becomes active
 * @param constrainer \c $0 owningView \c $1 target
 */
    @discardableResult func constrainTo(_ constraint: NSLayoutConstraint) -> Self {
        self.constrainTo { _, _ in constraint }
    }

    @discardableResult func constrainTo(_ constrainer: @escaping (UIView, LayoutTarget) -> NSLayoutConstraint) -> Self {
        self.constrainToAll { [ constrainer( $0, $1 ) ] }
    }

    @discardableResult func constrainToAll(constrainers: @escaping (UIView, LayoutTarget) -> [NSLayoutConstraint]) -> Self {
        self.constrainers.append( constrainers )
        return self
    }

    @discardableResult func constrain(to host: UIView? = nil, margins: Bool = false, anchors: Anchor = .box) -> Self {
        if anchors.contains( .top ) {
            self.constrainTo {
                if margins {
                    return (host ?? $0).layoutMarginsGuide.topAnchor.constraint( equalTo: $1.topAnchor )
                }
                else {
                    return (host ?? $0).topAnchor.constraint( equalTo: $1.topAnchor )
                }
            }
        }
        if anchors.contains( .leading ) {
            self.constrainTo {
                if margins {
                    return (host ?? $0).layoutMarginsGuide.leadingAnchor.constraint( equalTo: $1.leadingAnchor )
                }
                else {
                    return (host ?? $0).leadingAnchor.constraint( equalTo: $1.leadingAnchor )
                }
            }
        }
        if anchors.contains( .trailing ) {
            self.constrainTo {
                if margins {
                    return (host ?? $0).layoutMarginsGuide.trailingAnchor.constraint( equalTo: $1.trailingAnchor )
                }
                else {
                    return (host ?? $0).trailingAnchor.constraint( equalTo: $1.trailingAnchor )
                }
            }
        }
        if anchors.contains( .bottom ) {
            self.constrainTo {
                if margins {
                    return (host ?? $0).layoutMarginsGuide.bottomAnchor.constraint( equalTo: $1.bottomAnchor )
                }
                else {
                    return (host ?? $0).bottomAnchor.constraint( equalTo: $1.bottomAnchor )
                }
            }
        }
        if anchors.contains( .left ) {
            self.constrainTo {
                if margins {
                    return (host ?? $0).layoutMarginsGuide.leftAnchor.constraint( equalTo: $1.leftAnchor )
                }
                else {
                    return (host ?? $0).leftAnchor.constraint( equalTo: $1.leftAnchor )
                }
            }
        }
        if anchors.contains( .right ) {
            self.constrainTo {
                if margins {
                    return (host ?? $0).layoutMarginsGuide.rightAnchor.constraint( equalTo: $1.rightAnchor )
                }
                else {
                    return (host ?? $0).rightAnchor.constraint( equalTo: $1.rightAnchor )
                }
            }
        }
        if anchors.contains( .width ) {
            self.constrainTo {
                if margins {
                    return (host ?? $0).layoutMarginsGuide.widthAnchor.constraint( equalTo: $1.widthAnchor )
                }
                else {
                    return (host ?? $0).widthAnchor.constraint( equalTo: $1.widthAnchor )
                }
            }
        }
        if anchors.contains( .height ) {
            self.constrainTo {
                if margins {
                    return (host ?? $0).layoutMarginsGuide.heightAnchor.constraint( equalTo: $1.heightAnchor )
                }
                else {
                    return (host ?? $0).heightAnchor.constraint( equalTo: $1.heightAnchor )
                }
            }
        }
        if anchors.contains( .centerX ) {
            self.constrainTo {
                if margins {
                    return (host ?? $0).layoutMarginsGuide.centerXAnchor.constraint( equalTo: $1.centerXAnchor )
                }
                else {
                    return (host ?? $0).centerXAnchor.constraint( equalTo: $1.centerXAnchor )
                }
            }
        }
        if anchors.contains( .centerY ) {
            self.constrainTo {
                if margins {
                    return (host ?? $0).layoutMarginsGuide.centerYAnchor.constraint( equalTo: $1.centerYAnchor )
                }
                else {
                    return (host ?? $0).centerYAnchor.constraint( equalTo: $1.centerYAnchor )
                }
            }
        }

        return self
    }

    //! Activate this constraint when the configuration becomes active.
    @discardableResult func compressionResistanceRequired() -> Self {
        self.compressionResistance( horizontal: .required, vertical: .required )
    }

    @discardableResult func compressionResistance(horizontal: UILayoutPriority = UILayoutPriority( -1 ), vertical: UILayoutPriority = UILayoutPriority( -1 )) -> Self {
        self.activeProperties["compressionResistance.horizontal"] = horizontal
        self.activeProperties["compressionResistance.vertical"] = vertical
        return self
    }

    @discardableResult func huggingRequired() -> Self {
        self.hugging( horizontal: .required, vertical: .required )
    }

    @discardableResult func hugging(horizontal: UILayoutPriority = UILayoutPriority( -1 ), vertical: UILayoutPriority = UILayoutPriority( -1 )) -> Self {
        self.activeProperties["hugging.horizontal"] = horizontal
        self.activeProperties["hugging.vertical"] = vertical
        return self
    }

    //! Mark the view as needing layout after activating the configuration.  Useful if it has custom layout code.
    @discardableResult func needsLayout(_ view: UIView) -> Self {
        self.layoutViews.append( WeakBox( view ) )
        return self
    }

    //! Mark the view as needing a redraw after activating the configuration.  Useful if it has custom draw code.
    @discardableResult func needsDisplay(_ view: UIView) -> Self {
        self.displayViews.append( WeakBox( view ) )
        return self
    }

    //! Run this action when the configuration becomes active.
    @discardableResult func perform(_ action: @escaping (UIView) -> ()) -> Self {
        self.actions.append( action )
        return self
    }

    //! Request that this configuration's target become the first responder when the configuration becomes active.
    @discardableResult func becomeFirstResponder() -> Self {
        self.perform { $0.becomeFirstResponder() }
    }

    //! Request that this configuration's target resigns first responder when the configuration becomes active.
    @discardableResult func resignFirstResponder() -> Self {
        self.perform { $0.resignFirstResponder() }
    }

    //! Set a given value for the target at the given key, when the configuration becomes active.  If reverses, restore the old value when deactivated.
    @discardableResult func set(_ value: @escaping @autoclosure () -> Any?, forKey keyPath: String, reverses: Bool = false) -> Self {
        self.activeValues[keyPath] = value
        if reverses {
            self.inactiveValues[keyPath] = self.target.view?.value( forKeyPath: keyPath )
        }

        return self
    }

//@discardableResult func setFloat:(CGFloat)value forKey:(NSString *)key -> Self {}
//@discardableResult func setPoint:(CGPoint)value forKey:(NSString *)key -> Self {}
//@discardableResult func setSize:(CGSize)value forKey:(NSString *)key -> Self {}
//@discardableResult func setRect:(CGRect)value forKey:(NSString *)key -> Self {}
//@discardableResult func setTransform:(CGAffineTransform)value forKey:(NSString *)key -> Self {}
//@discardableResult func setEdgeInsets:(UIEdgeInsets)value forKey:(NSString *)key -> Self {}
//@discardableResult func setOffset:(UIOffset)value forKey:(NSString *)key -> Self {}

    //! Activate this configuration and apply its operations.
    @discardableResult func activate(animationDuration duration: TimeInterval = -1, parent: LayoutConfiguration? = nil) -> Self {
        guard !self.activation
        else { return self }
        guard duration < 0
        else {
            UIView.animate( withDuration: duration ) { self.activate( parent: parent ) }
            return self
        }
        trc( "%@: activate: %@", parent?.target, self )

        DispatchQueue.main.perform {
            UIView.animate( withDuration: duration ) {
                let owningView = self.target.owningView
                let targetView = self.target.view ?? owningView

                self.inactiveConfigurations.forEach {
                    trc( "%@:%@: -> deactivate inactive child: %@", parent?.target, self.target, $0 )
                    $0.deactivate( parent: self )
                }

                if let newPriority = self.activeProperties["compressionResistance.horizontal"] as? UILayoutPriority,
                   let oldPriority = targetView?.contentCompressionResistancePriority( for: .horizontal ),
                   newPriority != oldPriority {
                    self.inactiveProperties["compressionResistance.horizontal"] = oldPriority
                    targetView?.setContentCompressionResistancePriority( newPriority, for: .horizontal )
                }
                if let newPriority = self.activeProperties["compressionResistance.vertical"] as? UILayoutPriority,
                   let oldPriority = targetView?.contentCompressionResistancePriority( for: .vertical ),
                   newPriority != oldPriority {
                    self.inactiveProperties["compressionResistance.vertical"] = oldPriority
                    targetView?.setContentCompressionResistancePriority( newPriority, for: .vertical )
                }
                if let newPriority = self.activeProperties["hugging.horizontal"] as? UILayoutPriority,
                   let oldPriority = targetView?.contentHuggingPriority( for: .horizontal ),
                   newPriority != oldPriority {
                    self.inactiveProperties["hugging.horizontal"] = oldPriority
                    targetView?.setContentHuggingPriority( newPriority, for: .horizontal )
                }
                if let newPriority = self.activeProperties["hugging.vertical"] as? UILayoutPriority,
                   let oldPriority = targetView?.contentHuggingPriority( for: .vertical ),
                   newPriority != oldPriority {
                    self.inactiveProperties["hugging.vertical"] = oldPriority
                    targetView?.setContentHuggingPriority( newPriority, for: .vertical )
                }

                if !self.constrainers.isEmpty {
                    if let owningView = owningView {
                        targetView?.translatesAutoresizingMaskIntoConstraints = false
                        for constrainer in self.constrainers {
                            for constraint in constrainer( owningView, self.target ) {
                                trc( "%@:%@: activating %@", parent?.target, self.target, constraint )
                                constraint.isActive = true
                                self.activeConstraints.insert( constraint )
                            }
                        }
                    }
                    else {
                        assert( owningView != nil, "Skipping layout constraints since view has no owner: \(self.target)" )
                    }
                }

                self.activeValues.forEach { keyPath, newSupplier in
                    let newValue = newSupplier(), oldValue = self.target.view?.value( forKeyPath: keyPath ) as? NSObject
                    if newValue as? NSObject == oldValue {
                        return
                    }

                    if self.inactiveValues.keys.contains( keyPath ) {
                        self.inactiveValues[keyPath] = oldValue
                    }

                    trc( "%@:%@: %@, %@ -> %@", parent?.target, self.target, keyPath, oldValue.debugDescription, newValue.debugDescription )
                    self.target.view?.setValue( newValue, forKeyPath: keyPath )
                }
                Theme.current.observers.register( observer: self )

                targetView.flatMap { targetView in self.actions.forEach { $0( targetView ) } }
                self.activeConfigurations.forEach {
                    trc( "%@:%@: -> activate active child: %@", parent?.target, self.target, $0 )
                    $0.activate( parent: self )
                }

                self.activation = true

                self.layoutViews.forEach { $0.value?.setNeedsLayout() }
                self.displayViews.forEach { $0.value?.setNeedsDisplay() }

                if parent == nil {
                    self.layoutIfNeeded()
                }
            }
        }

        return self
    }

    //! Deactivate this configuration and reverse its relevant operations.
    @discardableResult func deactivate(animationDuration duration: TimeInterval = -1, parent: LayoutConfiguration? = nil) -> Self {
        guard self.activation
        else { return self }
        guard duration < 0
        else {
            UIView.animate( withDuration: duration ) { self.deactivate( parent: parent ) }
            return self
        }
        trc( "%@: deactivate: %@", parent?.target, self )

        DispatchQueue.main.perform {
            let owningView = self.target.owningView
            let targetView = self.target.view ?? owningView

            self.activeConfigurations.forEach {
                trc( "%@:%@: -> deactivate active child: %@", parent?.target, self.target, $0 )
                $0.deactivate( parent: self )
            }

            if let newPriority = self.inactiveProperties["compressionResistance.horizontal"] as? UILayoutPriority,
               newPriority != targetView?.contentCompressionResistancePriority( for: .horizontal ) {
                targetView?.setContentCompressionResistancePriority( newPriority, for: .horizontal )
            }
            if let newPriority = self.inactiveProperties["compressionResistance.vertical"] as? UILayoutPriority,
               newPriority != targetView?.contentCompressionResistancePriority( for: .vertical ) {
                targetView?.setContentCompressionResistancePriority( newPriority, for: .vertical )
            }
            if let newPriority = self.inactiveProperties["hugging.horizontal"] as? UILayoutPriority,
               newPriority != targetView?.contentHuggingPriority( for: .horizontal ) {
                targetView?.setContentHuggingPriority( newPriority, for: .horizontal )
            }
            if let newPriority = self.inactiveProperties["hugging.vertical"] as? UILayoutPriority,
               newPriority != targetView?.contentHuggingPriority( for: .vertical ) {
                targetView?.setContentHuggingPriority( newPriority, for: .vertical )
            }

            self.activeConstraints.forEach {
                trc( "%@:%@: deactivating %@", parent?.target, self.target, $0 )
                $0.isActive = false
            }
            self.activeConstraints.removeAll()

            self.inactiveValues.forEach { keyPath, newValue in
                let oldValue = self.target.view?.value( forKeyPath: keyPath ) as? NSObject
                if newValue as? NSObject == oldValue {
                    return
                }

                trc( "%@:%@: %@, %@ -> %@", parent?.target, self.target, keyPath, oldValue.debugDescription, newValue.debugDescription )
                self.target.view?.setValue( newValue, forKeyPath: keyPath )
            }
            Theme.current.observers.unregister( observer: self )

            self.inactiveConfigurations.forEach {
                trc( "%@:%@: -> activate inactive child: %@", parent?.target, self.target, $0 )
                $0.activate( parent: self )
            }

            self.activation = false

            self.layoutViews.forEach { $0.value?.setNeedsLayout() }
            self.displayViews.forEach { $0.value?.setNeedsDisplay() }

            if parent == nil {
                self.layoutIfNeeded()
            }
        }

        return self
    }

    func layoutIfNeeded() {
        if let owningView = self.target.owningView,
           (owningView as? UIWindow ?? owningView.window) != nil {
            owningView.layoutIfNeeded()
        }
    }

    // MARK: --- ThemeObserver ---

    public func didChangeTheme() {
        guard self.activated
        else { return }

        self.activeValues.forEach { keyPath, newSupplier in
            let newValue = newSupplier(), oldValue = self.target.view?.value( forKeyPath: keyPath ) as? NSObject
            if newValue as? NSObject == oldValue {
                return
            }

            trc( "[update] %@: %@, %@ -> %@", self.target, keyPath, oldValue.debugDescription, newValue.debugDescription )
            self.target.view?.setValue( newValue, forKeyPath: keyPath )
        }
    }
}
