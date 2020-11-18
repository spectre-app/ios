//
// Created by Maarten Billemont on 2020-09-11.
// Copyright (c) 2020 Lyndir. All rights reserved.
//

import UIKit

extension CGPath {
    static func between(_ fromRect: CGRect, _ toRect: CGRect) -> CGPath {
        let path = CGMutablePath()

        if abs( fromRect.minX - toRect.minX ) < abs( fromRect.maxX - toRect.maxX ) {
            let p1 = fromRect.left, p2 = toRect.topLeft
            path.move( to: p1 )
            path.addLine( to: CGPoint( x: p2.x, y: p1.y ) )
            path.addLine( to: p2 )
            path.addLine( to: toRect.bottomLeft )
        }
        else {
            let p1 = fromRect.right, p2 = toRect.topRight
            path.move( to: p1 )
            path.addLine( to: CGPoint( x: p2.x, y: p1.y ) )
            path.addLine( to: p2 )
            path.addLine( to: toRect.bottomRight )
        }

        return path
    }
}

extension CGRect {
    var center:      CGPoint {
        CGPoint( x: self.minX + (self.maxX - self.minX) / 2, y: self.minY + (self.maxY - self.minY) / 2 )
    }
    var top:         CGPoint {
        CGPoint( x: self.minX + (self.maxX - self.minX) / 2, y: self.minY )
    }
    var topLeft:     CGPoint {
        CGPoint( x: self.minX, y: self.minY )
    }
    var topRight:    CGPoint {
        CGPoint( x: self.maxX, y: self.minY )
    }
    var left:        CGPoint {
        CGPoint( x: self.minX, y: self.minY + (self.maxY - self.minY) / 2 )
    }
    var right:       CGPoint {
        CGPoint( x: self.maxX, y: self.minY + (self.maxY - self.minY) / 2 )
    }
    var bottom:      CGPoint {
        CGPoint( x: self.minX + (self.maxX - self.minX) / 2, y: self.maxY )
    }
    var bottomLeft:  CGPoint {
        CGPoint( x: self.minX, y: self.maxY )
    }
    var bottomRight: CGPoint {
        CGPoint( x: self.maxX, y: self.maxY )
    }

    init(center: CGPoint, radius: CGFloat) {
        self.init( x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2 )
    }

    init(center: CGPoint, size: CGSize) {
        self.init( x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height )
    }
}

extension CGPoint {
    public static func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint( x: lhs.x + rhs.x, y: lhs.y + rhs.y )
    }

    public static func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint( x: lhs.x - rhs.x, y: lhs.y - rhs.y )
    }

    public static func +=(lhs: inout CGPoint, rhs: CGPoint) {
        lhs.x += rhs.x
        lhs.y += rhs.y
    }

    public static func -=(lhs: inout CGPoint, rhs: CGPoint) {
        lhs.x -= rhs.x
        lhs.y -= rhs.y
    }
}

extension CGSize {
    public static func +(lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize( width: lhs.width + rhs.width, height: lhs.height + rhs.height )
    }

    public static func -(lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize( width: lhs.width - rhs.width, height: lhs.height - rhs.height )
    }

    public static func +=(lhs: inout CGSize, rhs: CGSize) {
        lhs.width += rhs.width
        lhs.height += rhs.height
    }

    public static func -=(lhs: inout CGSize, rhs: CGSize) {
        lhs.width -= rhs.width
        lhs.height -= rhs.height
    }

    var isEmpty: Bool {
        self.width == 0 || self.height == 0
    }

    init(_ point: CGPoint) {
        self.init( width: point.x, height: point.y )
    }

    func union(_ size: CGSize) -> CGSize {
        size.width <= self.width && size.height <= self.height ? self:
                size.width >= self.width && size.height >= self.height ? size:
                CGSize( width: max( self.width, size.width ), height: max( self.height, size.height ) )
    }

    func grow(width: CGFloat = 0, height: CGFloat = 0, size: CGSize = .zero, point: CGPoint = .zero) -> CGSize {
        let width  = width + size.width + point.x
        let height = height + size.height + point.y
        return width == 0 && height == 0 ? self:
                CGSize( width: self.width + width, height: self.height + height )
    }
}

extension UIEdgeInsets {
    public static func border(_ inset: CGFloat = 8) -> UIEdgeInsets {
        UIEdgeInsets( top: inset, left: inset, bottom: inset, right: inset )
    }

    public static func border(horizontal: CGFloat, vertical: CGFloat) -> UIEdgeInsets {
        UIEdgeInsets( top: vertical, left: horizontal, bottom: vertical, right: horizontal )
    }

    public static func horizontal(_ inset: CGFloat = 8) -> UIEdgeInsets {
        UIEdgeInsets( top: 0, left: inset, bottom: 0, right: inset )
    }

    public static func vertical(_ inset: CGFloat = 8) -> UIEdgeInsets {
        UIEdgeInsets( top: inset, left: 0, bottom: inset, right: 0 )
    }

    prefix public static func -(a: UIEdgeInsets) -> UIEdgeInsets {
        UIEdgeInsets( top: -a.top, left: -a.left, bottom: -a.bottom, right: -a.right )
    }

    public static func +(lhs: UIEdgeInsets, rhs: UIEdgeInsets) -> UIEdgeInsets {
        UIEdgeInsets( top: max( lhs.top, rhs.top ), left: max( lhs.left, rhs.left ),
                      bottom: max( lhs.bottom, rhs.bottom ), right: max( lhs.right, rhs.right ) )
    }

    public static func -(lhs: UIEdgeInsets, rhs: UIEdgeInsets) -> UIEdgeInsets {
        UIEdgeInsets( top: min( lhs.top, rhs.top ), left: min( lhs.left, rhs.left ),
                      bottom: min( lhs.bottom, rhs.bottom ), right: min( lhs.right, rhs.right ) )
    }

    public static func +=(lhs: inout UIEdgeInsets, rhs: UIEdgeInsets) {
        lhs.top = max( lhs.top, rhs.top )
        lhs.left = max( lhs.left, rhs.left )
        lhs.bottom = max( lhs.bottom, rhs.bottom )
        lhs.right = max( lhs.right, rhs.right )
    }

    public static func -=(lhs: inout UIEdgeInsets, rhs: UIEdgeInsets) {
        lhs.top = min( lhs.top, rhs.top )
        lhs.left = min( lhs.left, rhs.left )
        lhs.bottom = min( lhs.bottom, rhs.bottom )
        lhs.right = min( lhs.right, rhs.right )
    }

    var width:  CGFloat {
        self.left + self.right
    }
    var height: CGFloat {
        self.top + self.bottom
    }
    var size:   CGSize {
        CGSize( width: self.width, height: self.height )
    }

    init(in boundingRect: CGRect, subtracting subtractRect: CGRect) {
        if !boundingRect.intersects( subtractRect ) {
            self = .zero
        }
        else {
            let boundingTopLeft     = boundingRect.topLeft
            let boundingBottomRight = boundingRect.bottomRight
            let subtractTopLeft     = subtractRect.topLeft
            let subtractBottomRight = subtractRect.bottomRight
            let topLeftInset        = subtractBottomRight - boundingTopLeft
            let bottomRightInset    = boundingBottomRight - subtractTopLeft

            let top    = subtractTopLeft.y <= boundingTopLeft.y && subtractBottomRight.y < boundingBottomRight.y ? max( 0, topLeftInset.y ): 0
            let left   = subtractTopLeft.x <= boundingTopLeft.x && subtractBottomRight.x < boundingBottomRight.x ? max( 0, topLeftInset.x ): 0
            let bottom = subtractTopLeft.y > boundingTopLeft.y && subtractBottomRight.y >= boundingBottomRight.y ? max( 0, bottomRightInset.y ): 0
            let right  = subtractTopLeft.x > boundingTopLeft.x && subtractBottomRight.x >= boundingBottomRight.x ? max( 0, bottomRightInset.x ): 0

            self.init( top: top, left: left, bottom: bottom, right: right )
        }
    }
}

extension NSLayoutConstraint {
    func with(priority: UILayoutPriority) -> Self {
        self.priority = priority
        return self
    }
}

extension UICollectionView {

    func register(_ type: UICollectionViewCell.Type, nib: UINib? = nil) {
        if let nib = nib {
            self.register( nib, forCellWithReuseIdentifier: NSStringFromClass( type ) )
        }
        else {
            self.register( type, forCellWithReuseIdentifier: NSStringFromClass( type ) )
        }
    }

    func register(_ type: UICollectionReusableView.Type, supplementaryKind kind: String, nib: UINib? = nil) {
        if let nib = nib {
            self.register( nib, forSupplementaryViewOfKind: kind, withReuseIdentifier: NSStringFromClass( type ) )
        }
        else {
            self.register( type, forSupplementaryViewOfKind: kind, withReuseIdentifier: NSStringFromClass( type ) )
        }
    }

    func register(_ type: UICollectionReusableView.Type, decorationKind kind: String) {
        self.collectionViewLayout.register( type, forDecorationViewOfKind: kind )
    }

    func register(_ nib: UINib, decorationKind kind: String) {
        self.collectionViewLayout.register( nib, forDecorationViewOfKind: kind )
    }

    @discardableResult
    public func requestSelection(item: Int?, inSection section: Int = 0,
                                 animated: Bool = UIView.areAnimationsEnabled, scrollPosition: ScrollPosition = .centeredVertically)
                    -> Bool {
        if let item = item {
            let x = IndexPath( item: item, section: section )
            return self.requestSelection( at: x, animated: animated, scrollPosition: scrollPosition )
        } else {
            return self.requestSelection( at: nil, animated: animated, scrollPosition: scrollPosition )
        }
    }

    @discardableResult
    public func requestSelection(at selectPath: IndexPath?, animated: Bool = UIView.areAnimationsEnabled, scrollPosition: ScrollPosition = .centeredVertically)
                    -> Bool {
        let selectedPath = self.indexPathsForSelectedItems?.first

        if let selectPath = selectPath, selectPath == selectedPath ||
                !(self.delegate?.collectionView?( self, shouldSelectItemAt: selectPath ) ?? true) {
            return false
        }
        if let selectedPath = selectedPath, selectedPath.item != selectPath?.item &&
                !(self.delegate?.collectionView?( self, shouldDeselectItemAt: selectedPath ) ?? true) {
            return false
        }

        self.selectItem( at: selectPath, animated: animated, scrollPosition: scrollPosition )

        if let selectedPath = selectedPath {
            self.delegate?.collectionView?( self, didDeselectItemAt: selectedPath )
        }
        if let selectPath = selectPath {
            self.delegate?.collectionView?( self, didSelectItemAt: selectPath )
        }

        return true
    }
}

extension UICollectionReusableView {
    static func dequeue(from collectionView: UICollectionView, kind: String, indexPath: IndexPath) -> Self {
        collectionView.dequeueReusableSupplementaryView( ofKind: kind, withReuseIdentifier: NSStringFromClass( self ), for: indexPath ) as! Self
    }
}

extension UICollectionViewCell {
    static func dequeue(from collectionView: UICollectionView, indexPath: IndexPath) -> Self {
        collectionView.dequeueReusableCell( withReuseIdentifier: NSStringFromClass( self ), for: indexPath ) as! Self
    }
}

@available(iOS 13, *)
extension UIContextMenuConfiguration {
    var indexPath: IndexPath? {
        self.identifier as? IndexPath
    }
    var action:    UIAction? {
        get {
            objc_getAssociatedObject( self, &Key.action ) as? UIAction
        }
        set {
            objc_setAssociatedObject( self, &Key.action, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN )
        }
    }

    var event: MPTracker.TimedEvent? {
        get {
            objc_getAssociatedObject( self, &Key.event ) as? MPTracker.TimedEvent
        }
        set {
            objc_setAssociatedObject( self, &Key.event, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN )
        }
    }

    convenience init(indexPath: IndexPath,
                     previewProvider: ((UIContextMenuConfiguration) -> UIViewController?)? = nil,
                     actionProvider: (([UIMenuElement], UIContextMenuConfiguration) -> UIMenu?)? = nil) {
        var previewProvider = PreviewProvider( provider: previewProvider )
        var actionProvider  = ActionProvider( provider: actionProvider )
        self.init( identifier: indexPath as NSIndexPath,
                   previewProvider: { previewProvider.provide() },
                   actionProvider: { actionProvider.provide( $0 ) } )
        previewProvider.configuration = self
        actionProvider.configuration = self
    }

    // MARK: --- Types ---

    private struct Key {
        static var action = 0
        static var event  = 1
    }
}

@available(iOS 13, *)
fileprivate struct PreviewProvider {
    let provider:      ((UIContextMenuConfiguration) -> UIViewController?)?
    var configuration: UIContextMenuConfiguration?

    func provide() -> UIViewController? {
        self.configuration.flatMap { self.provider?( $0 ) }
    }
}

@available(iOS 13, *)
fileprivate struct ActionProvider {
    let provider:      (([UIMenuElement], UIContextMenuConfiguration) -> UIMenu?)?
    var configuration: UIContextMenuConfiguration?

    func provide(_ elements: [UIMenuElement]) -> UIMenu? {
        self.configuration.flatMap { self.provider?( elements, $0 ) }
    }
}

extension UIControl {
    private struct Key {
        static var actionHandlers = 0
    }

    var actionHandlers: [UIControlHandler] {
        get {
            objc_getAssociatedObject( self, &Key.actionHandlers ) as? [UIControlHandler] ?? []
        }
        set {
            objc_setAssociatedObject( self, &Key.actionHandlers, newValue, .OBJC_ASSOCIATION_RETAIN )
        }
    }

    func action(for controlEvents: UIControl.Event, _ action: @escaping () -> Void) {
        self.action( for: controlEvents, UIControlHandler( { control, event in action() } ) )
    }

    func action(for controlEvents: UIControl.Event, _ action: @escaping (UIEvent) -> Void) {
        self.action( for: controlEvents, UIControlHandler( { control, event in action( event ) } ) )
    }

    func action(for controlEvents: UIControl.Event, _ action: @escaping (UIEvent, UIControl?) -> Void) -> Void {
        self.action( for: controlEvents, UIControlHandler( { control, event in action( event, control ) } ) )
    }

    func action(for controlEvents: UIControl.Event, _ handler: UIControlHandler) -> Void {
        self.actionHandlers.append( handler )
        self.addTarget( handler, action: #selector( UIControlHandler.action ), for: controlEvents )
    }
}

class UIControlHandler: NSObject {
    private let actionHandler: (UIControl?, UIEvent) -> Void

    public init(_ eventHandler: @escaping (UIControl?, UIEvent) -> ()) {
        self.actionHandler = eventHandler
    }

    @objc
    func action(_ sender: UIControl?, _ event: UIEvent) {
        self.actionHandler( sender, event )
    }
}

extension UIColor {

    // Extended sRGB, hex, RRGGBB / RRGGBBAA
    class func hex(_ hex: String, alpha: CGFloat = .on) -> UIColor? {
        var hexSanitized = hex.trimmingCharacters( in: .whitespacesAndNewlines )
        hexSanitized = hexSanitized.replacingOccurrences( of: "#", with: "" )
        var rgb: UInt32  = 0
        var r:   CGFloat = 0.0
        var g:   CGFloat = 0.0
        var b:   CGFloat = 0.0
        var a:   CGFloat = alpha
        guard Scanner( string: hexSanitized ).scanHexInt32( &rgb )
        else { return nil }
        if hexSanitized.count == 6 {
            r = CGFloat( (rgb & 0xFF0000) >> 16 ) / 255.0
            g = CGFloat( (rgb & 0x00FF00) >> 8 ) / 255.0
            b = CGFloat( rgb & 0x0000FF ) / 255.0
        }
        else if hexSanitized.count == 8 {
            r = CGFloat( (rgb & 0xFF000000) >> 24 ) / 255.0
            g = CGFloat( (rgb & 0x00FF0000) >> 16 ) / 255.0
            b = CGFloat( (rgb & 0x0000FF00) >> 8 ) / 255.0
            a *= CGFloat( rgb & 0x000000FF ) / 255.0
        }
        else {
            return nil
        }

        return UIColor( red: r, green: g, blue: b, alpha: a )
    }

    var hex: String {
        var r = CGFloat( 0 ), g = CGFloat( 0 ), b = CGFloat( 0 ), a = CGFloat( 0 )
        self.getRed( &r, green: &g, blue: &b, alpha: &a )

        return String( format: "%0.2lX%0.2lX%0.2lX,%0.2lX", Int( r * 255 ), Int( g * 255 ), Int( b * 255 ), Int( a * 255 ) )
    }

    // Determine how common a color is in a list of colors.
    // Compares the color to the other colors only by average hue distance.
    func similarityOfHue(in colors: [UIColor]) -> CGFloat {
        let swatchHue = self.hue

        var commonality: CGFloat = 0
        for color in colors {
            let colorHue = color.hue
            commonality += abs( colorHue - swatchHue )
        }

        return commonality / CGFloat( colors.count )
    }

    var hue: CGFloat {
        var hue: CGFloat = 0
        self.getHue( &hue, saturation: nil, brightness: nil, alpha: nil )

        return hue
    }

    var saturation: CGFloat {
        var saturation: CGFloat = 0
        self.getHue( nil, saturation: &saturation, brightness: nil, alpha: nil )

        return saturation
    }

    var brightness: CGFloat {
        var brightness: CGFloat = 0
        self.getHue( nil, saturation: nil, brightness: &brightness, alpha: nil )

        return brightness
    }

    var alpha: CGFloat {
        var alpha: CGFloat = 0
        self.getHue( nil, saturation: nil, brightness: nil, alpha: &alpha )

        return alpha
    }

    func with(alpha newAlpha: CGFloat?) -> UIColor {
        var hue:        CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha:      CGFloat = 0
        self.getHue( &hue, saturation: &saturation, brightness: &brightness, alpha: &alpha )

        return UIColor( hue: hue, saturation: saturation, brightness: brightness, alpha: newAlpha ?? alpha )
    }

    func with(hue newHue: CGFloat?) -> UIColor {
        var hue:        CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha:      CGFloat = 0
        self.getHue( &hue, saturation: &saturation, brightness: &brightness, alpha: &alpha )

        return UIColor( hue: newHue ?? hue, saturation: saturation, brightness: brightness, alpha: alpha )
    }

    func with(saturation newSaturation: CGFloat?) -> UIColor {
        var hue:        CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha:      CGFloat = 0
        self.getHue( &hue, saturation: &saturation, brightness: &brightness, alpha: &alpha )

        return UIColor( hue: hue, saturation: newSaturation ?? saturation, brightness: brightness, alpha: alpha )
    }

    func with(brightness newBrightness: CGFloat?) -> UIColor {
        var hue:        CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha:      CGFloat = 0
        self.getHue( &hue, saturation: &saturation, brightness: &brightness, alpha: &alpha )

        return UIColor( hue: hue, saturation: saturation, brightness: newBrightness ?? brightness, alpha: alpha )
    }
}

extension UIFont {
    func withSymbolicTraits(_ symbolicTraits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        if let descriptor = self.fontDescriptor.withSymbolicTraits( symbolicTraits ) {
            return UIFont( descriptor: descriptor, size: self.pointSize )
        }

        return self
    }
}

extension UITableView {
    func register(_ type: UITableViewCell.Type, nib: UINib? = nil) {
        if let nib = nib {
            self.register( nib, forCellReuseIdentifier: NSStringFromClass( type ) )
        }
        else {
            self.register( type, forCellReuseIdentifier: NSStringFromClass( type ) )
        }
    }
}

extension UITableViewCell {
    static func dequeue<C: UITableViewCell>(from tableView: UITableView, indexPath: IndexPath, _ initializer: ((C) -> ())? = nil) -> Self {
        let cell = tableView.dequeueReusableCell( withIdentifier: NSStringFromClass( self ), for: indexPath ) as! C

        if let initialize = initializer {
            initialize( cell )
        }

        return cell as! Self
    }
}

extension UITraitCollection {
    @available(iOS 13.0, *)
    func resolveAsCurrent<R>(_ perform: () -> R) -> R {
        var result: R!
        self.performAsCurrent { result = perform() }

        return result
    }
}

extension UIView {
    public static func find(superviewOf child: UIView) -> Self? {
        var superview = child.superview
        while superview != nil {
            if let superview = superview as? Self {
                return superview
            }

            superview = superview?.superview
        }

        return nil
    }

    public var ownership: (owner: UIResponder, property: String)? {
        var nextResponder = self.next
        while let nextResponder_ = nextResponder {
            if let property = nextResponder_.property( withValue: self ) {
                return (nextResponder_, property)
            }

            nextResponder = nextResponder_.next
        }

        return nil
    }
}
