//
// Created by Maarten Billemont on 2019-07-18.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

class ConstraintResolver: CustomStringConvertible {
    let view: UIView
    let axis: NSLayoutConstraint.Axis?
    var constraints = Set<NSLayoutConstraint>()
    var description: String {
        if self.constraints.isEmpty {
            self.constraints = self.scan()
        }

        return self.constraints.sorted { $1.debugDescription > $0.debugDescription }.reduce( "" ) { description, constraint in
            if self.axis == nil || constraint.firstAttribute.on( axis: self.axis! ) || constraint.secondAttribute.on( axis: self.axis! ) {
                return (description.isEmpty ? "": "\(description)\n") + constraint.debugDescription
            }

            return description
        }
    }

    init(for view: UIView, axis: NSLayoutConstraint.Axis? = nil) {
        self.view = view
        self.axis = axis
    }

    func constraints(affecting item: NSObject, for axis: NSLayoutConstraint.Axis? = nil) -> Set<NSLayoutConstraint> {
        var constraints     = Set<NSLayoutConstraint>()
        var holder: UIView? = (item as? UIView) ?? (item as? UILayoutGuide)?.owningView
        while let holder_ = holder {
            for constraint in holder_.constraints {
                if constraint.firstItem === item || constraint.secondItem === item {
                    if axis == nil || constraint.firstAttribute.on( axis: axis! ) || constraint.secondAttribute.on( axis: axis! ) {
                        constraints.insert( constraint )
                    }
                }
            }
            holder = holder_.superview
        }

        return constraints
    }

    func scan() -> Set<NSLayoutConstraint> {
        var scannedConstraints = Set<NSLayoutConstraint>()

        var scannedHosts = [ NSObject ](), scanHosts: [NSObject] = [ self.view ]
        while !scanHosts.isEmpty {
            // Get the next view to scan
            let host = scanHosts.removeFirst()
            guard !scannedHosts.contains( host )
            else {
                continue
            }
            scannedHosts.append( host )

            // Scan the view by collecting all of its un-scanned constraints
            var hostConstraints = self.constraints( affecting: host, for: self.axis )
            hostConstraints.subtract( scannedConstraints )
            scannedConstraints.formUnion( hostConstraints )

            // Search the collected constraints for additional views to scan
            for constraint in hostConstraints {
                if let other = constraint.firstItem as? NSObject, other !== host, !scannedHosts.contains( other ) {
                    scanHosts.append( other )
                }
                if let other = constraint.secondItem as? NSObject, other !== host, !scannedHosts.contains( other ) {
                    scanHosts.append( other )
                }
            }
        }

        if self.axis == nil || self.axis == .vertical {
            scannedConstraints.formUnion( self.view.constraintsAffectingLayout( for: .vertical ) )
        }
        if self.axis == nil || self.axis == .horizontal {
            scannedConstraints.formUnion( self.view.constraintsAffectingLayout( for: .horizontal ) )
        }

        return scannedConstraints
    }

    enum Edge: CustomStringConvertible {
        case top, centerV, bottom
        case leading, centerH, trailing

        var description: String {
            switch self {
                case .top:
                    return "top"
                case .centerV:
                    return "centerV"
                case .bottom:
                    return "bottom"
                case .leading:
                    return "leading"
                case .centerH:
                    return "centerH"
                case .trailing:
                    return "trailing"
            }
        }

        func siblings() -> Set<Edge> {
            switch self {
                case .top, .centerV, .bottom:
                    return Set( arrayLiteral: .top, .centerV, .bottom ).subtracting( [ self ] )

                case .leading, .centerH, .trailing:
                    return Set( arrayLiteral: .leading, .centerH, .trailing ).subtracting( [ self ] )
            }
        }

        static func edges(for attribute: NSLayoutConstraint.Attribute) -> [Edge] {
            switch attribute {
                case .left, .leading, .leftMargin, .leadingMargin:
                    return [ .leading ]
                case .right, .trailing, .rightMargin, .trailingMargin:
                    return [ .trailing ]
                case .top, .topMargin:
                    return [ .top ]
                case .bottom, .bottomMargin:
                    return [ .bottom ]
                case .width:
                    return [ .leading, .trailing ]
                case .height:
                    return [ .top, .bottom ]
                case .centerX, .centerXWithinMargins:
                    return [ .centerH ]
                case .centerY, .centerYWithinMargins:
                    return [ .centerV ]
                case .lastBaseline:
                    return [] // TODO
                case .firstBaseline:
                    return [] // TODO
                case .notAnAttribute:
                    return []
                @unknown default:
                    return []
            }
        }
    }
}

extension NSLayoutConstraint {
    open override var debugDescription: String {
        var firstItem: String?, secondItem: String?, depth = 0
        var holder                                         = self.holder
        while holder != nil {
            depth += 1
            holder = holder?.superview
        }

        if let first = self.firstItem, self.firstAttribute.description != "?" {
            firstItem = "\((first as? UIView)?.infoName() ?? (first as? UILayoutGuide)?.identifier ?? String( describing: first )): \(self.firstAttribute)"
        }
        if let second = self.secondItem, self.secondAttribute.description != "?" {
            secondItem = "\((second as? UIView)?.infoName() ?? (second as? UILayoutGuide)?.identifier ?? String( describing: second )): \(self.secondAttribute)"
        }

        var modifier = ""
        if self.multiplier != 1 {
            modifier += " *\(self.multiplier)"
        }
        if self.constant != 0 {
            modifier += " \(self.constant, sign: true)"
        }
        var priority = ""
        if self.priority != .required {
            priority = " @\(self.priority.rawValue)"
        }

        if let firstItem = firstItem, let secondItem = secondItem {
            return String( repeating: "+", count: depth ) + "[ \(firstItem) ] \(self.relation) [ \(secondItem) ]\(modifier)\(priority)"
        }
        else if let firstItem = firstItem {
            return String( repeating: "+", count: depth ) + "[ \(firstItem) ] \(self.relation)\(modifier)\(priority)"
        }
        else if let secondItem = secondItem {
            return String( repeating: "+", count: depth ) + "[ \(secondItem) ] \(self.relation)\(modifier)\(priority)"
        }

        return self.description
    }

    open var holder: UIView? {
        var view = (self.firstItem as? UIView) ?? (self.firstItem as? UILayoutGuide)?.owningView ??
                (self.secondItem as? UIView) ?? (self.secondItem as? UILayoutGuide)?.owningView
        while let view_ = view {
            if view_.constraints.contains( self ) {
                return view_
            }
            view = view_.superview
        }

        return nil
    }

//    open override var hash: Int {
//        var hasher = Hasher()
//        if let item = self.firstItem as? NSObject {
//            hasher.combine( item )
//        }
//        hasher.combine( self.firstAttribute )
//        hasher.combine( self.relation )
//        if let item = self.secondItem as? NSObject {
//            hasher.combine( item )
//        }
//        hasher.combine( self.secondAttribute )
//        hasher.combine( self.multiplier )
//        hasher.combine( self.constant )
//        hasher.combine( self.priority )
////        hasher.combine( self.isActive )
////        hasher.combine( self.identifier )
//        return hasher.finalize()
//    }
//
//    open override func isEqual(_ object: Any?) -> Bool {
//        guard let object = object as? NSLayoutConstraint
//        else {
//            return false
//        }
//        if self === object {
//            return true
//        }
//
//        return self.firstItem === object.firstItem && self.firstAttribute == object.firstAttribute
//                && self.secondItem === object.secondItem && self.secondAttribute == object.secondAttribute
//                && self.multiplier == object.multiplier && self.constant == object.constant
//                && self.relation == object.relation && self.priority == object.priority
////                && self.isActive == object.isActive && self.identifier == object.identifier
//    }
}

extension NSLayoutConstraint.Attribute: CustomStringConvertible {
    public var description: String {
        switch self {
            case .left:
                return "left"
            case .right:
                return "right"
            case .top:
                return "top"
            case .bottom:
                return "bottom"
            case .leading:
                return "leading"
            case .trailing:
                return "trailing"
            case .width:
                return "width"
            case .height:
                return "height"
            case .centerX:
                return "centerX"
            case .centerY:
                return "centerY"
            case .lastBaseline:
                return "lastBaseline"
            case .firstBaseline:
                return "firstBaseline"
            case .leftMargin:
                return "leftMargin"
            case .rightMargin:
                return "rightMargin"
            case .topMargin:
                return "topMargin"
            case .bottomMargin:
                return "bottomMargin"
            case .leadingMargin:
                return "leadingMargin"
            case .trailingMargin:
                return "trailingMargin"
            case .centerXWithinMargins:
                return "centerXWithinMargins"
            case .centerYWithinMargins:
                return "centerYWithinMargins"
            case .notAnAttribute:
                return "notAnAttribute"
            @unknown default:
                return "?"
        }
    }

    public func on(axis: NSLayoutConstraint.Axis) -> Bool {
        switch self {
            case .left:
                return axis == .horizontal
            case .right:
                return axis == .horizontal
            case .top:
                return axis == .vertical
            case .bottom:
                return axis == .vertical
            case .leading:
                return axis == .horizontal
            case .trailing:
                return axis == .horizontal
            case .width:
                return axis == .horizontal
            case .height:
                return axis == .vertical
            case .centerX:
                return axis == .horizontal
            case .centerY:
                return axis == .vertical
            case .lastBaseline:
                return axis == .horizontal
            case .firstBaseline:
                return axis == .horizontal
            case .leftMargin:
                return axis == .horizontal
            case .rightMargin:
                return axis == .horizontal
            case .topMargin:
                return axis == .vertical
            case .bottomMargin:
                return axis == .vertical
            case .leadingMargin:
                return axis == .horizontal
            case .trailingMargin:
                return axis == .horizontal
            case .centerXWithinMargins:
                return axis == .horizontal
            case .centerYWithinMargins:
                return axis == .vertical
            case .notAnAttribute:
                return false
            @unknown default:
                return false
        }
    }
}

extension NSLayoutConstraint.Relation: CustomStringConvertible {
    public var description: String {
        switch self {
            case .lessThanOrEqual:
                return "<="
            case .equal:
                return "=="
            case .greaterThanOrEqual:
                return ">="
            @unknown default:
                return "?"
        }
    }
}
