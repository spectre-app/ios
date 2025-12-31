//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import SwiftUI

extension EdgeInsets {
    public static var zero: Self = .border(.zero)

    public static func border(_ inset: CGFloat = .spectre.padding) -> Self {
        Self(top: inset, leading: inset, bottom: inset, trailing: inset)
    }

    public static func border(horizontal: CGFloat, vertical: CGFloat) -> Self {
        Self(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
    }

    public static func horizontal(_ inset: CGFloat = .spectre.padding) -> Self {
        Self(top: .zero, leading: inset, bottom: .zero, trailing: inset)
    }

    public static func vertical(_ inset: CGFloat = .spectre.padding) -> Self {
        Self(top: inset, leading: .zero, bottom: inset, trailing: .zero)
    }

    public static prefix func - (insets: Self) -> Self {
        Self(top: -insets.top, leading: -insets.leading, bottom: -insets.bottom, trailing: -insets.trailing)
    }

    public static func + (lhs: Self, rhs: Self) -> Self {
        Self(
            top: lhs.top + rhs.top, leading: lhs.leading + rhs.leading,
            bottom: lhs.bottom + rhs.bottom, trailing: lhs.trailing + rhs.trailing
        )
    }

    public static func - (lhs: Self, rhs: Self) -> Self {
        Self(
            top: lhs.top - rhs.top, leading: lhs.leading - rhs.leading,
            bottom: lhs.bottom - rhs.bottom, trailing: lhs.trailing - rhs.trailing
        )
    }

    public static func += (lhs: inout Self, rhs: Self) {
        lhs.top += rhs.top
        lhs.leading += rhs.leading
        lhs.bottom += rhs.bottom
        lhs.trailing += rhs.trailing
    }

    public static func -= (lhs: inout Self, rhs: Self) {
        lhs.top -= rhs.top
        lhs.leading -= rhs.leading
        lhs.bottom -= rhs.bottom
        lhs.trailing -= rhs.trailing
    }

    var width:  CGFloat {
        self.leading + self.trailing
    }

    var height: CGFloat {
        self.top + self.bottom
    }

    var size:   CGSize {
        CGSize(width: self.width, height: self.height)
    }
}

extension EdgeInsets: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.top)
        hasher.combine(self.leading)
        hasher.combine(self.trailing)
        hasher.combine(self.bottom)
    }
}

extension View {
    @inlinable
    public func unmask(alignment: Alignment = .center, @ViewBuilder _ mask: () -> some View) -> some View {
        self.mask {
            Rectangle().overlay(alignment: alignment) {
                mask().blendMode(.destinationOut)
            }
        }
    }

    public func `if`(_ condition: @autoclosure () -> Bool = true, @ViewBuilder then ifTrue: (Self) -> some View) -> AnyView {
        self.if(condition(), then: ifTrue, else: { $0 })
    }

    public func `if`(_ condition: @autoclosure () -> Bool = true, @ViewBuilder then ifTrue: (Self) -> some View,
                     @ViewBuilder else ifFalse: (Self) -> some View)
        -> AnyView {
        if condition() {
            AnyView(ifTrue(self))
        }
        else {
            AnyView(ifFalse(self))
        }
    }

    public func `if`<V>(`let` value: @autoclosure () -> V?, @ViewBuilder then ifTrue: (Self, V) -> some View) -> AnyView {
        if let value = value() {
            AnyView(ifTrue(self, value))
        }
        else {
            AnyView(self)
        }
    }

    public func `if`<V>(`let` value: @autoclosure () -> V?, @ViewBuilder then ifTrue: (Self, V) -> some View,
                        @ViewBuilder else ifFalse: (Self) -> some View)
        -> AnyView {
        if let value = value() {
            AnyView(ifTrue(self, value))
        }
        else {
            AnyView(ifFalse(self))
        }
    }

    public func modify(@ViewBuilder _ modifier: (Self) -> some View) -> some View {
        modifier(self)
    }

    public func paddingEffect(_ padding: CGFloat) -> some View {
        self.modifier(PaddingEffectModifier(padding: padding))
    }
}

private struct PaddingEffectModifier: ViewModifier {
    let padding: CGFloat

    @State
    private var size: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGSize.self) { $0.size } action: { self.size = $0 }
            .scaleEffect(
                x: 1 - self.padding / (self.size.width.nonEmpty ?? .on),
                y: 1 - self.padding / (self.size.height.nonEmpty ?? .on)
            )
    }
}

extension View {
    /// While this view's geometry is empty, remove it from the layout. The view is added back when the geometry becomes non-empty again.
    public func removeWhenEmpty() -> some View {
        self.modifier(RemoveWhenEmptyModifier())
    }
}

private var removeEmptyViews: Set<UUID> = []
private struct RemoveWhenEmptyModifier: ViewModifier {
    @State
    private var id: UUID = .init()
    @State
    private var retry: Bool? = true

    func body(content: Content) -> some View {
        if self.retry != nil {
            if removeEmptyViews.remove(self.id) == nil {
                content.onGeometryChange(for: Bool.self, of: \.size.isEmpty) { isEmpty in
                    if isEmpty {
                        removeEmptyViews.insert(self.id)
                        self.retry?.toggle()
                    }
                }
            }
            else {
                EmptyView()
            }
        }
    }
}

extension Color.Resolved {
    public init?(colorSpace: Color.RGBColorSpace = .sRGB, hex: String, opacity: Float = 1) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb:   UInt64  = 0
        var red:   Float = 0.0
        var green: Float = 0.0
        var blue:  Float = 0.0
        var opacity: Float = opacity

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb)
        else { return nil }

        if hexSanitized.count == 6 {
            red = Float((rgb & 0xFF0000) >> 16) / 255.0
            green = Float((rgb & 0x00FF00) >> 8) / 255.0
            blue = Float(rgb & 0x0000FF) / 255.0
        }
        else if hexSanitized.count == 8 {
            red = Float((rgb & 0xFF00_0000) >> 24) / 255.0
            green = Float((rgb & 0x00FF_0000) >> 16) / 255.0
            blue = Float((rgb & 0x0000_FF00) >> 8) / 255.0
            opacity *= Float(rgb & 0x0000_00FF) / 255.0
        }
        else {
            return nil
        }

        self.init(colorSpace: colorSpace, red: red, green: green, blue: blue, opacity: opacity)
    }
}

extension Spacer {
    public static func equalWidth(_ equalWidth: Binding<CGFloat>) -> some View {
        Self(minLength: .zero)
            .frame(maxWidth: equalWidth.wrappedValue)
    }
}

extension Binding {
    public func nonEmpty<V>(default: V) -> Binding<V> where Value == V? {
        .init(
            get: { self.wrappedValue ?? `default` },
            set: { self.wrappedValue = $0 }
        )
    }

    public func inverse() -> Binding<Bool> where Value == Bool {
        .init(
            get: { !self.wrappedValue },
            set: { self.wrappedValue = !$0 }
        )
    }

    public func isSet<O>() -> Binding<Bool> where Value == O? {
        .init(
            get: { self.wrappedValue != nil },
            set: {
                if !$0 {
                    self.wrappedValue = nil
                }
            }
        )
    }
}

extension Alignment {
    public var edges: Edge.Set {
        switch self.horizontal {
            case .leading, .listRowSeparatorLeading: .leading
            case .trailing, .listRowSeparatorTrailing: .trailing
            default:
                switch self.vertical {
                    case .top, .firstTextBaseline: .top
                    case .bottom, .lastTextBaseline: .bottom
                    default: .init()
                }
        }
    }
}

extension TextAlignment {
    public var horizontal: HorizontalAlignment {
        switch self {
            case .leading: .leading
            case .center: .center
            case .trailing: .trailing
        }
    }
}

extension HorizontalAlignment {
    public func vertically(_ vertical: VerticalAlignment = .center) -> Alignment {
        .init(horizontal: self, vertical: vertical)
    }

    public var sign: CGFloat {
        switch self {
            case .leading, .listRowSeparatorLeading: -1
            case .trailing, .listRowSeparatorTrailing: 1
            default: 0
        }
    }
}

extension VerticalAlignment {
    public func horizontally(_ horizontal: HorizontalAlignment = .center) -> Alignment {
        .init(horizontal: horizontal, vertical: self)
    }

    public var sign: CGFloat {
        switch self {
            case .top, .firstTextBaseline: -1
            case .bottom, .lastTextBaseline: 1
            default: 0
        }
    }
}

public struct OverflowView<Content: View>: View {
    @State
    var maxHeight: CGFloat = .infinity
    @State
    var spacing: CGFloat?
    @ViewBuilder
    var content: () -> Content

    @State
    private var contentHeight: CGFloat = .zero

    public var body: some View {
        ScrollView {
            VStack(spacing: self.spacing) {
                self.content()
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { self.contentHeight = $0 }
        }
        .frame(maxHeight: min(self.maxHeight, self.contentHeight))
    }
}
