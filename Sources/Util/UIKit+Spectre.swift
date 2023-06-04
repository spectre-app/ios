//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import SafariServices
import UIKit

// extension SFSafariViewController: ThemeObserver {
//    convenience init(url: URL) {
//        self.init( url: url, configuration: Configuration() )
//
//        self.dismissButtonStyle = .close
//        self.modalPresentationStyle = .pageSheet
//
//        Theme.current.observers.register( observer: self )?
//             .didChange( theme: Theme.current )
//    }
//
//    // MARK: - ThemeObserver
//
//    func didChange(theme: Theme) {
//        self.preferredBarTintColor = theme.color.backdrop.get(forTraits: self.traitCollection)
//        self.preferredControlTintColor = theme.color.tint.get(forTraits: self.traitCollection)
//    }
// }

extension CGPath {
    static func between(_ fromRect: CGRect, _ toRect: CGRect) -> CGPath {
        let path = CGMutablePath()

        if abs(fromRect.minX - toRect.minX) < abs(fromRect.maxX - toRect.maxX) {
            let p1 = fromRect.left, p2 = toRect.topLeft
            path.move(to: p1)
            path.addLine(to: CGPoint(x: p2.x, y: p1.y))
            path.addLine(to: p2)
            path.addLine(to: toRect.bottomLeft)
        }
        else {
            let p1 = fromRect.right, p2 = toRect.topRight
            path.move(to: p1)
            path.addLine(to: CGPoint(x: p2.x, y: p1.y))
            path.addLine(to: p2)
            path.addLine(to: toRect.bottomRight)
        }

        return path
    }
}

extension CGRect {
    var center:      CGPoint {
        CGPoint(x: self.minX + (self.maxX - self.minX) / 2, y: self.minY + (self.maxY - self.minY) / 2)
    }

    var top:         CGPoint {
        CGPoint(x: self.minX + (self.maxX - self.minX) / 2, y: self.minY)
    }

    var topLeft:     CGPoint {
        CGPoint(x: self.minX, y: self.minY)
    }

    var topRight:    CGPoint {
        CGPoint(x: self.maxX, y: self.minY)
    }

    var left:        CGPoint {
        CGPoint(x: self.minX, y: self.minY + (self.maxY - self.minY) / 2)
    }

    var right:       CGPoint {
        CGPoint(x: self.maxX, y: self.minY + (self.maxY - self.minY) / 2)
    }

    var bottom:      CGPoint {
        CGPoint(x: self.minX + (self.maxX - self.minX) / 2, y: self.maxY)
    }

    var bottomLeft:  CGPoint {
        CGPoint(x: self.minX, y: self.maxY)
    }

    var bottomRight: CGPoint {
        CGPoint(x: self.maxX, y: self.maxY)
    }

    init(center: CGPoint, radius: CGFloat) {
        self.init(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }

    init(center: CGPoint, size: CGSize) {
        self.init(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    }
}

public func max(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
    CGPoint(x: Swift.max(lhs.x, rhs.x), y: Swift.max(lhs.y, rhs.y))
}

public func min(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
    CGPoint(x: Swift.min(lhs.x, rhs.x), y: Swift.min(lhs.y, rhs.y))
}

extension CGPoint {
    static prefix func - (point: Self) -> Self {
        Self(x: -point.x, y: -point.y)
    }

    public static func + (lhs: Self, rhs: Self) -> Self {
        Self(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    public static func - (lhs: Self, rhs: Self) -> Self {
        Self(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    public static func += (lhs: inout Self, rhs: Self) {
        lhs.x += rhs.x
        lhs.y += rhs.y
    }

    public static func -= (lhs: inout Self, rhs: Self) {
        lhs.x -= rhs.x
        lhs.y -= rhs.y
    }
}

public func max(_ lhs: CGSize, _ rhs: CGSize) -> CGSize {
    CGSize(width: Swift.max(lhs.width, rhs.width), height: Swift.max(lhs.height, rhs.height))
}

public func min(_ lhs: CGSize, _ rhs: CGSize) -> CGSize {
    CGSize(width: Swift.min(lhs.width, rhs.width), height: Swift.min(lhs.height, rhs.height))
}

extension CGSize {
    public static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }

    public static func - (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width - rhs.width, height: lhs.height - rhs.height)
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
        self.width == .zero || self.height == .zero
    }

    init(_ point: CGPoint) {
        self.init(width: point.x, height: point.y)
    }

    func union(_ size: CGSize) -> CGSize {
        size.width <= self.width && size.height <= self.height
            ? self
            : size.width >= self.width && size.height >= self.height
                ? size
                : CGSize(width: max(self.width, size.width), height: max(self.height, size.height))
    }

    func grow(width: CGFloat = .zero, height: CGFloat = .zero, size: CGSize = .zero, point: CGPoint = .zero) -> CGSize {
        let width  = width + size.width + point.x
        let height = height + size.height + point.y
        return width == .zero && height == .zero
            ? self
            : CGSize(width: self.width + width, height: self.height + height)
    }
}

public func max(_ lhs: UIEdgeInsets, _ rhs: UIEdgeInsets) -> UIEdgeInsets {
    UIEdgeInsets(
        top: Swift.max(lhs.top, rhs.top), left: Swift.max(lhs.left, rhs.left),
        bottom: Swift.max(lhs.bottom, rhs.bottom), right: Swift.max(lhs.right, rhs.right)
    )
}

public func min(_ lhs: UIEdgeInsets, _ rhs: UIEdgeInsets) -> UIEdgeInsets {
    UIEdgeInsets(
        top: Swift.min(lhs.top, rhs.top), left: Swift.min(lhs.left, rhs.left),
        bottom: Swift.min(lhs.bottom, rhs.bottom), right: Swift.min(lhs.right, rhs.right)
    )
}

extension UIEdgeInsets {
    public static func border(_ inset: CGFloat = .spectre.padding) -> UIEdgeInsets {
        UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
    }

    public static func border(horizontal: CGFloat, vertical: CGFloat) -> UIEdgeInsets {
        UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }

    public static func horizontal(_ inset: CGFloat = .spectre.padding) -> UIEdgeInsets {
        UIEdgeInsets(top: .zero, left: inset, bottom: .zero, right: inset)
    }

    public static func vertical(_ inset: CGFloat = .spectre.padding) -> UIEdgeInsets {
        UIEdgeInsets(top: inset, left: .zero, bottom: inset, right: .zero)
    }

    public static prefix func - (insets: UIEdgeInsets) -> UIEdgeInsets {
        UIEdgeInsets(top: -insets.top, left: -insets.left, bottom: -insets.bottom, right: -insets.right)
    }

    public static func + (lhs: UIEdgeInsets, rhs: UIEdgeInsets) -> UIEdgeInsets {
        UIEdgeInsets(
            top: lhs.top + rhs.top, left: lhs.left + rhs.left,
            bottom: lhs.bottom + rhs.bottom, right: lhs.right + rhs.right
        )
    }

    public static func - (lhs: UIEdgeInsets, rhs: UIEdgeInsets) -> UIEdgeInsets {
        UIEdgeInsets(
            top: lhs.top - rhs.top, left: lhs.left - rhs.left,
            bottom: lhs.bottom - rhs.bottom, right: lhs.right - rhs.right
        )
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
        CGSize(width: self.width, height: self.height)
    }

    init(in bounds: CGRect, removing remove: CGRect) {
        if !bounds.intersects(remove) {
            self = .zero
        }
        else {
            let topLeftInset     = max(.zero, remove.bottomRight - bounds.topLeft)
            let bottomRightInset = max(.zero, bounds.bottomRight - remove.topLeft)

            let top    = remove.topLeft.y <= bounds.topLeft.y && remove.bottomRight.y < bounds.bottomRight.y ? topLeftInset.y : .zero
            let left   = remove.topLeft.x <= bounds.topLeft.x && remove.bottomRight.x < bounds.bottomRight.x ? topLeftInset.x : .zero
            let bottom = remove.topLeft.y > bounds.topLeft.y && remove.bottomRight.y >= bounds.bottomRight.y ? bottomRightInset.y : .zero
            let right  = remove.topLeft.x > bounds.topLeft.x && remove.bottomRight.x >= bounds.bottomRight.x ? bottomRightInset.x : .zero

            self.init(top: top, left: left, bottom: bottom, right: right)
        }
    }
}

extension UIView {
    public var ownership: (owner: UIResponder, property: String)? {
        var nextResponder = self.next
        while let nextResponder_ = nextResponder {
            if let property = property(of: nextResponder_, withValue: self) {
                return (nextResponder_, property)
            }

            nextResponder = nextResponder_.next
        }

        return nil
    }
}

private let requiredQueue = DispatchQueue(label: "\(productName): Network Required", qos: .userInitiated, attributes: [.concurrent])
private let optionalQueue = DispatchQueue(label: "\(productName): Network Optional", qos: .background, attributes: [.concurrent])

extension URLSession {
    public static var required = LazyBox<URLSession> {
        guard !LeakRegistry.shared.isSuspended, !AppConfig.shared.offline
        else { return nil }

        return URLSession(configuration: requiredConfiguration(), delegate: nil, delegateQueue: OperationQueue(queue: requiredQueue))
    } unset: {
        $0.getAllTasks { $0.forEach { $0.cancel() } }
    }

    public static var optional = LazyBox<URLSession> {
        guard !LeakRegistry.shared.isSuspended, !AppConfig.shared.offline
        else { return nil }

        return URLSession(configuration: optionalConfiguration(), delegate: nil, delegateQueue: OperationQueue(queue: optionalQueue))
    } unset: {
        $0.getAllTasks { $0.forEach { $0.cancel() } }
    }

    public static func requiredConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpCookieStorage = nil
        configuration.httpAdditionalHeaders = [
            "User-Agent": "\(productName)/\(productVersion) " +
                "(\(UIDevice.current.model); CPU \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)) " +
                "Mozilla/5.0 AppleWebKit/605.1.15",
        ]
        configuration.sharedContainerIdentifier = productGroup
        configuration.networkServiceType = .responsiveData
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        return configuration
    }

    public static func optionalConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpCookieStorage = nil
        configuration.httpAdditionalHeaders = [
            "User-Agent": "\(productName)/\(productVersion) " +
                "(\(UIDevice.current.model); CPU \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)) " +
                "Mozilla/5.0 AppleWebKit/605.1.15",
        ]
        configuration.sharedContainerIdentifier = productGroup
        configuration.networkServiceType = .background
        configuration.timeoutIntervalForResource = TimeInterval(600 /* 10 min */ )
        configuration.isDiscretionary = true
        configuration.waitsForConnectivity = true
        configuration.allowsExpensiveNetworkAccess = false
        configuration.allowsConstrainedNetworkAccess = false
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        return configuration
    }
}
