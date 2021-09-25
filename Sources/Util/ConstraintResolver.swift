// =============================================================================
// Created by Maarten Billemont on 2019-07-18.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import UIKit

class ConstraintResolver: CustomDebugStringConvertible {
    let view: UIView
    let axis: NSLayoutConstraint.Axis?
    var constraints = [ NSLayoutConstraint ]()
    var debugDescription: String {
        if self.constraints.isEmpty {
            self.constraints = self.scan()
        }

        return self.constraints.reduce( "" ) { description, constraint in
            if self.axis == nil || constraint.firstAttribute.on( axis: self.axis! ) || constraint.secondAttribute.on( axis: self.axis! ) {
                return (description.isEmpty ? "": "\(description)\n") + String( reflecting: constraint )
            }

            return description
        }
    }

    init(for view: UIView, axis: NSLayoutConstraint.Axis? = nil) {
        self.view = view
        self.axis = axis
    }

    func constraints(affecting item: NSObject, for axis: NSLayoutConstraint.Axis? = nil) -> Set<HashableConstraint> {
        var constraints = Set<HashableConstraint>()
        var holder      = (item as? UIView) ?? (item as? UILayoutGuide)?.owningView
        while let holder_ = holder {
            for constraint in holder_.constraints
                where (constraint.firstItem === item || constraint.secondItem === item) &&
                      (axis == nil || constraint.firstAttribute.on( axis: axis! ) || constraint.secondAttribute.on( axis: axis! )) {
                constraints.insert( HashableConstraint( constraint: constraint ) )
            }
            holder = holder_.superview
        }

        return constraints
    }

    func scan() -> [NSLayoutConstraint] {
        var scannedConstraints = Set<HashableConstraint>()

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
                if let other = constraint.constraint.firstItem as? NSObject, other !== host, !scannedHosts.contains( other ) {
                    scanHosts.append( other )
                }
                if let other = constraint.constraint.secondItem as? NSObject, other !== host, !scannedHosts.contains( other ) {
                    scanHosts.append( other )
                }
            }
        }

        if self.axis == nil || self.axis == .vertical {
            scannedConstraints.formUnion(
                    self.view.constraintsAffectingLayout( for: .vertical ).map { HashableConstraint( constraint: $0 ) } )
        }
        if self.axis == nil || self.axis == .horizontal {
            scannedConstraints.formUnion(
                    self.view.constraintsAffectingLayout( for: .horizontal ).map { HashableConstraint( constraint: $0 ) } )
        }

        return scannedConstraints.map { $0.constraint }.sorted { String( reflecting: $1 ) > String( reflecting: $0 ) }
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
                    return Set( [ .top, .centerV, .bottom ] ).subtracting( [ self ] )

                case .leading, .centerH, .trailing:
                    return Set( [ .leading, .centerH, .trailing ] ).subtracting( [ self ] )
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

class HashableConstraint: Hashable {
    let constraint: NSLayoutConstraint

    init(constraint: NSLayoutConstraint) {
        self.constraint = constraint
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine( self.constraint.firstItem as? NSObject )
        hasher.combine( self.constraint.firstAttribute )
        hasher.combine( self.constraint.relation )
        hasher.combine( self.constraint.secondItem as? NSObject )
        hasher.combine( self.constraint.secondAttribute )
        hasher.combine( self.constraint.multiplier )
        hasher.combine( self.constraint.constant )
        hasher.combine( self.constraint.priority )
        hasher.combine( self.constraint.identifier )
        // hasher.combine( self.constraint.isActive )
    }

    static func == (lhs: HashableConstraint, rhs: HashableConstraint) -> Bool {
        lhs === rhs || lhs.constraint === rhs.constraint || lhs.constraint == rhs.constraint || (
                lhs.constraint.secondItem === rhs.constraint.secondItem && lhs.constraint.secondAttribute == rhs.constraint.secondAttribute
                && lhs.constraint.firstItem === rhs.constraint.firstItem && lhs.constraint.firstAttribute == rhs.constraint.firstAttribute
                && lhs.constraint.multiplier == rhs.constraint.multiplier && lhs.constraint.constant == rhs.constraint.constant
                && lhs.constraint.relation == rhs.constraint.relation && lhs.constraint.priority == rhs.constraint.priority
                && lhs.constraint.identifier == rhs.constraint.identifier //&& lhs.constraint.isActive == rhs.constraint.isActive
        )
    }
}

public extension NSLayoutConstraint {
    // @_dynamicReplacement(for: description) FIXME: https://bugs.swift.org/browse/SR-13121
    override var debugDescription: String {
        if self.firstAttribute.description.contains( "?" ) || self.secondAttribute.description.contains( "?" ) {
            return self.description
        }

        var firstItem: String?, secondItem: String?, depth = 0, holder = self.holder
        while holder != nil {
            depth += 1
            holder = holder?.superview
        }

        if let first = self.firstItem {
            firstItem = "\(self.describeItem( first )): \(self.firstAttribute)"
        }
        if let second = self.secondItem {
            secondItem = "\(self.describeItem( second )): \(self.secondAttribute)"
        }

        var modifier = ""
        if self.multiplier != 1 {
            modifier += " *\(self.multiplier)"
        }
        if self.constant != 0 || firstItem == nil || secondItem == nil {
            modifier += " \(number: self.constant, .signed)"
        }
        var priority = ""
        if self.priority != .required {
            priority = " @\(self.priority.rawValue)"
        }

        if let firstItem = firstItem, let secondItem = secondItem {
            return String( repeating: "+", count: depth ) +
                   "[ \(firstItem) ] \(self.relation) [ \(secondItem) ]\(modifier)\(priority): (\(self.description))"
        }
        else if let firstItem = firstItem {
            return String( repeating: "+", count: depth ) +
                   "[ \(firstItem) ] \(self.relation)\(modifier)\(priority): (\(self.description))"
        }
        else if let secondItem = secondItem {
            return String( repeating: "+", count: depth ) +
                   "[ \(secondItem) ] \(self.relation)\(modifier)\(priority): (\(self.description))"
        }

        return "[ no items ]: (\(self.description))"
    }

    var holder: UIView? {
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

    private func describeItem(_ item: AnyObject) -> String {
        if let view = item as? UIView {
            return view.describe()
        }
        else if let guide = item as? UILayoutGuide, let owningView = guide.owningView {
            let owner = owningView.describe()

            if guide.identifier == "UIViewLayoutMarginsGuide" {
                return "LM{\(owner)}"
            }
            else if guide.identifier == "UIViewReadableContentGuide" {
                return "RC{\(owner)}"
            }
            else if !guide.identifier.isEmpty {
                return "\(guide.identifier){\(owner)}"
            }
            else {
                return "L{\(owner)}"
            }
        }
        else {
            return String( reflecting: item )
        }
    }
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
                return "?(\(self.rawValue))"
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
