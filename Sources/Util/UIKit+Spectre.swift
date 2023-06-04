// =============================================================================
// Created by Maarten Billemont on 2020-09-11.
// Copyright (c) 2020 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import UIKit
import SafariServices

extension SFSafariViewController: ThemeObserver {
    convenience init(url: URL) {
        self.init( url: url, configuration: Configuration() )

        self.dismissButtonStyle = .close
        self.modalPresentationStyle = .pageSheet

        Theme.current.observers.register( observer: self )?
             .didChange( theme: Theme.current )
    }

    // MARK: - ThemeObserver

    func didChange(theme: Theme) {
        self.preferredBarTintColor = theme.color.backdrop.get(forTraits: self.traitCollection)
        self.preferredControlTintColor = theme.color.tint.get(forTraits: self.traitCollection)
    }
}

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

public func max(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
    CGPoint( x: Swift.max( lhs.x, rhs.x ), y: Swift.max( lhs.y, rhs.y ) )
}

public func min(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
    CGPoint( x: Swift.min( lhs.x, rhs.x ), y: Swift.min( lhs.y, rhs.y ) )
}

extension CGPoint {
    public static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint( x: lhs.x + rhs.x, y: lhs.y + rhs.y )
    }

    public static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint( x: lhs.x - rhs.x, y: lhs.y - rhs.y )
    }

    public static func += (lhs: inout CGPoint, rhs: CGPoint) {
        lhs.x += rhs.x
        lhs.y += rhs.y
    }

    public static func -= (lhs: inout CGPoint, rhs: CGPoint) {
        lhs.x -= rhs.x
        lhs.y -= rhs.y
    }
}

public func max(_ lhs: CGSize, _ rhs: CGSize) -> CGSize {
    CGSize( width: Swift.max( lhs.width, rhs.width ), height: Swift.max( lhs.height, rhs.height ) )
}

public func min(_ lhs: CGSize, _ rhs: CGSize) -> CGSize {
    CGSize( width: Swift.min( lhs.width, rhs.width ), height: Swift.min( lhs.height, rhs.height ) )
}

extension CGSize {
    public static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize( width: lhs.width + rhs.width, height: lhs.height + rhs.height )
    }

    public static func - (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize( width: lhs.width - rhs.width, height: lhs.height - rhs.height )
    }

    public static func += (lhs: inout CGSize, rhs: CGSize) {
        lhs.width += rhs.width
        lhs.height += rhs.height
    }

    public static func -= (lhs: inout CGSize, rhs: CGSize) {
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
        size.width <= self.width && size.height <= self.height ? self :
        size.width >= self.width && size.height >= self.height ? size :
        CGSize( width: max( self.width, size.width ), height: max( self.height, size.height ) )
    }

    func grow(width: CGFloat = 0, height: CGFloat = 0, size: CGSize = .zero, point: CGPoint = .zero) -> CGSize {
        let width  = width + size.width + point.x
        let height = height + size.height + point.y
        return width == 0 && height == 0 ? self :
               CGSize( width: self.width + width, height: self.height + height )
    }
}

public func max(_ lhs: UIEdgeInsets, _ rhs: UIEdgeInsets) -> UIEdgeInsets {
    UIEdgeInsets( top: Swift.max( lhs.top, rhs.top ), left: Swift.max( lhs.left, rhs.left ),
                  bottom: Swift.max( lhs.bottom, rhs.bottom ), right: Swift.max( lhs.right, rhs.right ) )
}

public func min(_ lhs: UIEdgeInsets, _ rhs: UIEdgeInsets) -> UIEdgeInsets {
    UIEdgeInsets( top: Swift.min( lhs.top, rhs.top ), left: Swift.min( lhs.left, rhs.left ),
                  bottom: Swift.min( lhs.bottom, rhs.bottom ), right: Swift.min( lhs.right, rhs.right ) )
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

    prefix public static func - (insets: UIEdgeInsets) -> UIEdgeInsets {
        UIEdgeInsets( top: -insets.top, left: -insets.left, bottom: -insets.bottom, right: -insets.right )
    }

    public static func + (lhs: UIEdgeInsets, rhs: UIEdgeInsets) -> UIEdgeInsets {
        UIEdgeInsets( top: lhs.top + rhs.top, left: lhs.left + rhs.left,
                      bottom: lhs.bottom + rhs.bottom, right: lhs.right + rhs.right )
    }

    public static func - (lhs: UIEdgeInsets, rhs: UIEdgeInsets) -> UIEdgeInsets {
        UIEdgeInsets( top: lhs.top - rhs.top, left: lhs.left - rhs.left,
                      bottom: lhs.bottom - rhs.bottom, right: lhs.right - rhs.right )
    }

    public static func += (lhs: inout UIEdgeInsets, rhs: UIEdgeInsets) {
        lhs.top += rhs.top
        lhs.left += rhs.left
        lhs.bottom += rhs.bottom
        lhs.right += rhs.right
    }

    public static func -= (lhs: inout UIEdgeInsets, rhs: UIEdgeInsets) {
        lhs.top -= rhs.top
        lhs.left -= rhs.left
        lhs.bottom -= rhs.bottom
        lhs.right -= rhs.right
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

    init(in bounds: CGRect, removing remove: CGRect) {
        if !bounds.intersects( remove ) {
            self = .zero
        }
        else {
            let topLeftInset     = max( .zero, remove.bottomRight - bounds.topLeft )
            let bottomRightInset = max( .zero, bounds.bottomRight - remove.topLeft )

            let top    = remove.topLeft.y <= bounds.topLeft.y && remove.bottomRight.y < bounds.bottomRight.y ? topLeftInset.y : 0
            let left   = remove.topLeft.x <= bounds.topLeft.x && remove.bottomRight.x < bounds.bottomRight.x ? topLeftInset.x : 0
            let bottom = remove.topLeft.y > bounds.topLeft.y && remove.bottomRight.y >= bounds.bottomRight.y ? bottomRightInset.y : 0
            let right  = remove.topLeft.x > bounds.topLeft.x && remove.bottomRight.x >= bounds.bottomRight.x ? bottomRightInset.x : 0

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

    public func requestSelection(item: Int?, inSection section: Int = 0,
                                 delegation: Bool = true, animated: Bool = UIView.areAnimationsEnabled,
                                 scrollPosition: ScrollPosition = [ .centeredHorizontally, .centeredVertically ]) {
        self.requestSelection( at: item.flatMap { [ IndexPath( item: $0, section: section ) ] } ?? [],
                               delegation: delegation, animated: animated, scrollPosition: scrollPosition )
    }

    public func requestSelection(at requestedPaths: [IndexPath],
                                 delegation: Bool = true, animated: Bool = UIView.areAnimationsEnabled,
                                 scrollPosition: ScrollPosition = [ .centeredHorizontally, .centeredVertically ]) {
        guard !self.bounds.isEmpty
        else { return }

        let delegate = delegation ? self.delegate : nil
        let selectionPaths = Set(
                // Select all requested items that are allowed to be selected.
                requestedPaths.filter {
                    $0.section < self.numberOfSections && $0.item < self.numberOfItems( inSection: $0.section ) &&
                    (delegate?.collectionView?( self, shouldSelectItemAt: $0 ) ?? true)
                }
        )
                // And all currently selected items that are not allowed to be deselected.
            .union( (self.indexPathsForSelectedItems ?? []).filter {
                !(delegate?.collectionView?( self, shouldDeselectItemAt: $0 ) ?? true)
            } )

        // Deselect currently selected items that are no longer selected.
        for itemPath in Set( self.indexPathsForSelectedItems ?? [] ).subtracting( selectionPaths ) {
            self.deselectItem( at: itemPath, animated: animated )
            delegate?.collectionView?( self, didDeselectItemAt: itemPath )
        }

        if (self.indexPathsForSelectedItems ?? []).elementsEqual( selectionPaths ),
           let firstItemPath = self.indexPathsForSelectedItems?.first {
            // Scroll to already selected items.
            self.scrollToItem( at: firstItemPath, at: scrollPosition, animated: animated )
        }
        else {
            // Select newly selected items.
            for itemPath in selectionPaths.subtracting( self.indexPathsForSelectedItems ?? [] ) {
                self.selectItem( at: itemPath, animated: animated, scrollPosition: scrollPosition )
                delegate?.collectionView?( self, didSelectItemAt: itemPath )
            }
        }
    }
}

extension UICollectionReusableView {
    static func dequeue(from collectionView: UICollectionView, kind: String, indexPath: IndexPath) -> Self {
        collectionView.dequeueReusableSupplementaryView(
                ofKind: kind, withReuseIdentifier: NSStringFromClass( self ), for: indexPath ) as! Self
        // swiftlint:disable:previous force_cast
    }
}

extension UICollectionViewCell {
    static func dequeue(from collectionView: UICollectionView, indexPath: IndexPath) -> Self {
        collectionView.dequeueReusableCell(
                withReuseIdentifier: NSStringFromClass( self ), for: indexPath ) as! Self
        // swiftlint:disable:previous force_cast
    }
}

extension UIContextMenuConfiguration {
    var indexPath: IndexPath? {
        self.identifier as? IndexPath
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
}

private struct PreviewProvider {
    let provider:      ((UIContextMenuConfiguration) -> UIViewController?)?
    var configuration: UIContextMenuConfiguration?

    func provide() -> UIViewController? {
        self.configuration.flatMap { self.provider?( $0 ) }
    }
}

private struct ActionProvider {
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
        self.action( for: controlEvents, UIControlHandler( { _, _ in action() } ) )
    }

    func action(for controlEvents: UIControl.Event, _ action: @escaping (UIEvent) -> Void) {
        self.action( for: controlEvents, UIControlHandler( { _, event in action( event ) } ) )
    }

    func action(for controlEvents: UIControl.Event, _ action: @escaping (UIEvent, UIControl?) -> Void) {
        self.action( for: controlEvents, UIControlHandler( { control, event in action( event, control ) } ) )
    }

    func action(for controlEvents: UIControl.Event, _ handler: UIControlHandler) {
        self.actionHandlers.append( handler )
        self.addTarget( handler, action: #selector( UIControlHandler.action ), for: controlEvents )
    }
}

class UIControlHandler: NSObject {
    private let actionHandler: (UIControl?, UIEvent) -> Void

    public init(_ eventHandler: @escaping (UIControl?, UIEvent) -> Void) {
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
        var rgb:   UInt64  = 0
        var red:   CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue:  CGFloat = 0.0
        var alpha: CGFloat = alpha
        guard Scanner( string: hexSanitized ).scanHexInt64( &rgb )
        else { return nil }
        if hexSanitized.count == 6 {
            red = CGFloat( (rgb & 0xFF0000) >> 16 ) / 255.0
            green = CGFloat( (rgb & 0x00FF00) >> 8 ) / 255.0
            blue = CGFloat( rgb & 0x0000FF ) / 255.0
        }
        else if hexSanitized.count == 8 {
            red = CGFloat( (rgb & 0xFF000000) >> 24 ) / 255.0
            green = CGFloat( (rgb & 0x00FF0000) >> 16 ) / 255.0
            blue = CGFloat( (rgb & 0x0000FF00) >> 8 ) / 255.0
            alpha *= CGFloat( rgb & 0x000000FF ) / 255.0
        }
        else {
            return nil
        }

        return UIColor( red: red, green: green, blue: blue, alpha: alpha )
    }

    var hex: String {
        var red = CGFloat( 0 ), green = CGFloat( 0 ), blue = CGFloat( 0 ), alpha = CGFloat( 0 )
        self.getRed( &red, green: &green, blue: &blue, alpha: &alpha )

        return String( format: "%0.2lX%0.2lX%0.2lX,%0.2lX", Int( red * 255 ), Int( green * 255 ), Int( blue * 255 ), Int( alpha * 255 ) )
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

    func with(
            hue newHue: CGFloat? = nil,
            saturation newSaturation: CGFloat? = nil,
            brightness newBrightness: CGFloat? = nil,
            alpha newAlpha: CGFloat? = nil
    ) -> UIColor {
        if newHue == nil, newSaturation == nil, newBrightness == nil, let newAlpha = newAlpha {
            return self.withAlphaComponent( newAlpha )
        }

        var hue:        CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha:      CGFloat = 0
        self.getHue( &hue, saturation: &saturation, brightness: &brightness, alpha: &alpha )

        return UIColor(
                hue: newHue ?? hue,
                saturation: newSaturation ?? saturation,
                brightness: newBrightness ?? brightness,
                alpha: newAlpha ?? alpha )
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

extension UIGestureRecognizer {
    convenience init(_ block: @escaping (Self) -> Void) {
        let receiver = Receiver( action: block )
        self.init( target: receiver, action: #selector( receiver.handle ) )
        objc_setAssociatedObject( self, #function, receiver, .OBJC_ASSOCIATION_RETAIN )
    }

    class Receiver<R: UIGestureRecognizer> {
        let action: (R) -> Void

        init(action: @escaping (R) -> Void) {
            self.action = action
        }

        @objc
        func handle(_ recognizer: UIGestureRecognizer) {
            if let recognizer = recognizer as? R {
                self.action( recognizer )
            }
        }
    }
}

extension UIImage {
    static func load(data: Data?) -> UIImage? {
        guard let data = data
        else { return nil }

        if let image = UIImage( data: data ) {
            return image
        }

        if let image = UIImage.svg( data: data ) {
            return image
        }

        return nil
    }
}

extension UIStackView {
    convenience init(arrangedSubviews views: [UIView], axis: NSLayoutConstraint.Axis = .horizontal,
                     alignment: UIStackView.Alignment = .fill, distribution: UIStackView.Distribution = .fill, spacing: CGFloat = 0) {
        self.init( arrangedSubviews: views )
        self.axis = axis
        self.alignment = alignment
        self.distribution = distribution
        self.spacing = spacing
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

    public func requestSelection(row: Int?, inSection section: Int = 0,
                                 delegation: Bool = true, animated: Bool = UIView.areAnimationsEnabled,
                                 scrollPosition: ScrollPosition = .middle) {
        self.requestSelection( at: row.flatMap { [ IndexPath( item: $0, section: section ) ] } ?? [],
                               delegation: delegation, animated: animated, scrollPosition: scrollPosition )
    }

    public func requestSelection(at requestedPaths: [IndexPath],
                                 delegation: Bool = true, animated: Bool = UIView.areAnimationsEnabled,
                                 scrollPosition: ScrollPosition = .middle) {
        guard !self.bounds.isEmpty
        else { return }

        let selectionPaths = Set<IndexPath>(
                // Select all requested items that are allowed to be selected.
                requestedPaths.compactMap {
                    guard $0.section < self.numberOfSections && $0.item < self.numberOfRows( inSection: $0.section )
                    else { return nil }
                    guard delegation, let delegate = self.delegate,
                          delegate.responds( to: #selector( UITableViewDelegate.tableView(_:willSelectRowAt:) ) )
                    else { return $0 }
                    return delegate.tableView?( self, willSelectRowAt: $0 )
                }
        )
                // And all currently selected items that are not allowed to be deselected.
            .union( (self.indexPathsForSelectedRows ?? []).compactMap {
                guard delegation, let delegate = self.delegate,
                      delegate.responds( to: #selector( UITableViewDelegate.tableView(_:willDeselectRowAt:) ) )
                else { return $0 }
                return delegate.tableView?( self, willDeselectRowAt: $0 )
            } )

        // Deselect currently selected items that are no longer selected.
        for itemPath in Set( self.indexPathsForSelectedRows ?? [] ).subtracting( selectionPaths ) {
            self.deselectRow( at: itemPath, animated: animated )
            self.delegate?.tableView?( self, didDeselectRowAt: itemPath )
        }

        if (self.indexPathsForSelectedRows ?? []).elementsEqual( selectionPaths ) {
            // Scroll to already selected items.
            self.scrollToNearestSelectedRow( at: scrollPosition, animated: animated )
        }
        else {
            // Select newly selected items.
            for itemPath in selectionPaths.subtracting( self.indexPathsForSelectedRows ?? [] ) {
                self.selectRow( at: itemPath, animated: animated, scrollPosition: scrollPosition )
                self.delegate?.tableView?( self, didSelectRowAt: itemPath )
            }
        }
    }
}

extension UITableViewCell {
    static func dequeue<C: UITableViewCell>(from tableView: UITableView, indexPath: IndexPath, _ initializer: ((C) -> Void)? = nil) -> C {
        let cell = tableView.dequeueReusableCell(
                withIdentifier: NSStringFromClass( self ), for: indexPath ) as! C
        // swiftlint:disable:previous force_cast

        if let initialize = initializer {
            UIView.performWithoutAnimation {
                initialize( cell )
            }
        }

        return cell
    }
}

extension UITraitCollection {
    func resolveAsCurrent<R>(_ perform: () -> R) -> R {
        var result: R!
        self.performAsCurrent { result = perform() }

        return result
    }
}

protocol _Animate {
    @MainActor
    static func _animate<V>(_ update: @escaping @MainActor () async throws -> V) async rethrows -> V

    @MainActor
    static func _performWithoutAnimation<V>(_ update: @escaping @MainActor () async throws -> V) async rethrows -> V
}

extension _Animate {
    @MainActor
    @available(iOS, deprecated: 13.0)
    static func _animate<V>(_ update: @escaping @MainActor () async throws -> V) async rethrows -> V {
        UIView.beginAnimations(nil, context: nil)
        UIView.setAnimationDuration(.short)
        defer { UIView.commitAnimations() }
        return try await update()
    }

    @MainActor
    @available(iOS, deprecated: 13.0)
    static func _performWithoutAnimation<V>(_ update: @escaping @MainActor () async throws -> V) async rethrows -> V {
        let wasEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(wasEnabled) }
        return try await update()
    }
}

extension UIView: _Animate {
    public func findSuperview<V: UIView>(ofType type: V.Type? = nil, where filter: ((V) -> Bool)? = nil) -> V? {
        var superview = self.superview
        while superview != nil {
            if let superview = superview as? V, filter?( superview ) ?? true {
                return superview
            }

            superview = superview?.superview
        }

        return nil
    }

    public func enumerateSubviews<V: UIView>(ofType type: V.Type? = nil, where filter: ((V) -> Bool)? = nil, execute: (V) -> Void) {
        for subview in self.subviews {
            if let subview = subview as? V, filter?( subview ) ?? true {
                execute( subview )
            }

            subview.enumerateSubviews( ofType: type, where: filter, execute: execute )
        }
    }

    public var ownership: (owner: UIResponder, property: String)? {
        var nextResponder = self.next
        while let nextResponder_ = nextResponder {
            if let property = property( of: nextResponder_, withValue: self ) {
                return (nextResponder_, property)
            }

            nextResponder = nextResponder_.next
        }

        return nil
    }

    @MainActor
    public static func animate<V>(_ update: @escaping @MainActor () async throws -> V) async rethrows -> V {
        try await (UIView.self as _Animate.Type)._animate(update)
    }

    @MainActor
    public static func performWithoutAnimation<V>(_ update: @escaping @MainActor () async throws -> V) async rethrows -> V {
        try await (UIView.self as _Animate.Type)._performWithoutAnimation(update)
    }
}
