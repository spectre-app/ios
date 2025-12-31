//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import SwiftUI

extension View {
    public func popoverForm<I: Identifiable>(item: Binding<I?>, @ViewBuilder content: @escaping (I) -> some View) -> some View {
        self.popover(item: item) { item in
            PopoverForm { content(item) }
        }
    }

    public func popoverForm(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> some View) -> some View {
        self.sheet(isPresented: isPresented) {
            PopoverForm(content: content)
        }
    }

    public func popoverTitle(_ title: String) -> some View {
        self.preference(key: PopoverTitle.self, value: title)
    }
}

struct PopoverTitle: PreferenceKey {
    static func reduce(value: inout String?, nextValue: () -> String?) {
        value = nextValue() ?? value
    }
}

struct PopoverForm<Content: View>: View {
    @ViewBuilder
    var content: () -> Content

    @State
    private var title: String?

    var body: some View {
        VStack(spacing: .zero) {
            self.title.flatMap(Text.init(verbatim:))
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .font(.spectre.largeTitle)
                .padding([.top, .horizontal], .spectre.margin)
                .shadow(color: .spectre.shadow, radius: .on)

            self.content()
        }
        .onPreferenceChange(PopoverTitle.self) { self.title = $0 }
        .background(alignment: .top) {
            GradientView(gradient: .stripes(tint: .spectre.panel))
                .ignoresSafeArea()
        }
        .spectreStyle(
            background: LinearGradient(
                colors: [.spectre.backdrop.opacity(.long), .spectre.backdrop, .spectre.backdrop.opacity(.short)],
                startPoint: .top, endPoint: .bottom,
            ))
    }
}

#if DEBUG
#Preview {
    Image(AppIcon.primary.glyphName).popoverForm(isPresented: .constant(true)) {
        Form {
            Text("Content!")
        }
        .popoverTitle("Title!")
    }
    .spectreStyle()
}
#endif
