//
//  SwiftUI+Spectre.swift
//  Spectre
//
//  Created by Maarten Billemont on 2023-04-02.
//  Copyright © 2023 Lyndir. All rights reserved.
//

import SwiftUI

public extension View {
    func frame(equalWidth: Binding<CGFloat>) -> some View {
        self.frame(minWidth: equalWidth.wrappedValue).background(GeometryReader { proxy in
            Path()
                .onAppear { equalWidth.wrappedValue = max(equalWidth.wrappedValue, proxy.size.width) }
                .onChange(of: proxy.size.width) { equalWidth.wrappedValue = max(equalWidth.wrappedValue, proxy.size.width) }
        })
    }
}

public extension Spacer {
    static func equalWidth(_ equalWidth: Binding<CGFloat>) -> some View {
        Self(minLength: .zero)
            .frame(maxWidth: equalWidth.wrappedValue)
    }
}

public extension AnyHashable {
    init(_ a: some Hashable, _ b: some Hashable) {
        self.init([AnyHashable(a), AnyHashable(b)])
    }

    init(_ a: some Hashable, _ b: some Hashable, _ c: some Hashable) {
        self.init([AnyHashable(a), AnyHashable(b), AnyHashable(c)])
    }

    init(_ a: some Hashable, _ b: some Hashable, _ c: some Hashable, _ d: some Hashable) {
        self.init([AnyHashable(a), AnyHashable(b), AnyHashable(c), AnyHashable(d)])
    }

    init(_ a: some Hashable, _ b: some Hashable, _ c: some Hashable, _ d: some Hashable, _ e: some Hashable) {
        self.init([AnyHashable(a), AnyHashable(b), AnyHashable(c), AnyHashable(d), AnyHashable(e)])
    }

    init(_ a: some Hashable, _ b: some Hashable, _ c: some Hashable, _ d: some Hashable, _ e: some Hashable, _ f: some Hashable) {
        self.init([AnyHashable(a), AnyHashable(b), AnyHashable(c), AnyHashable(d), AnyHashable(e), AnyHashable(f)])
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
            .background {
                GeometryReader { proxy in
                    Path()
                        .onAppear { self.contentHeight = proxy.size.height }
                        .onChange(of: proxy.size.height) { self.contentHeight = proxy.size.height }
                }
            }
        }
        .frame(maxHeight: min(self.maxHeight, self.contentHeight))
    }
}
