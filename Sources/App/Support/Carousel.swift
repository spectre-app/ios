//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import SwiftUI
import WrappingHStack
@_spi(Advanced) import SwiftUIIntrospect

struct Carousel<Value: Identifiable, Content: View>: View {
    let values: [Value]
    @Binding
    var selection: Value
    @ViewBuilder
    var content: (Value) -> Content

    @State
    private var width: CGFloat?

    var body: some View {
        ScrollViewReader { scroller in
            ScrollView(.horizontal) {
                WrappingHStack(horizontalSpacing: .spectre.padding, verticalSpacing: .spectre.padding) {
                    ForEach(self.values) { value in
                        let isSelected = value.id == self.selection.id
                        Button {
                            withAnimation {
                                self.$selection.wrappedValue = value
                            }
                        } label: {
                            self.content(value)
                                .background(isSelected ? Color.spectre.selection : nil)
                                .padding(-.spectre.padding)
                        }
                        .overlay(alignment: .topTrailing) {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .padding(.spectre.padding / 2)
                                    .background {
                                        Circle().fill(Color.spectre.panel)
                                    }
                                    .overlay {
                                        Circle().strokeBorder(Color.spectre.selection)
                                    }
                                    .padding(-.spectre.padding / 2)
                            }
                        }
                        .onChange(of: isSelected, initial: true) {
                            if isSelected {
                                withAnimation {
                                    scroller.scrollTo(value.id, anchor: .center)
                                }
                            }
                        }
                    }
                }
                .frame(minWidth: self.width)
                .padding(.spectre.padding)
                .padding(.horizontal, .spectre.margin)
            }
            .padding(.horizontal, -.spectre.margin)
            .modify {
                $0
                #if canImport(UIKit)
                .introspect(.scrollView, on: .iOS(.v18...)) {
                    $0.horizontalScrollIndicatorInsets = .init(top: .zero, left: .spectre.margin, bottom: .zero, right: .spectre.margin)
                }
                #endif
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { self.width = $0 }
        .listRowInsets(.zero)
    }
}

#if DEBUG
#Preview {
    @Previewable @State var selection = SpectreLogLevel.info
    VStack {
        Carousel(values: SpectreLogLevel.allCases, selection: $selection) {
            Text($0.tag)
                .frame(width: .spectre.control, height: .spectre.control)
        }

        Form {
            Carousel(values: SpectreLogLevel.allCases, selection: $selection) {
                Text($0.tag)
                    .frame(width: .spectre.control, height: .spectre.control)
            }

            GroupBox("Avatar") {
                Carousel(values: SpectreLogLevel.allCases, selection: $selection) {
                    Text($0.tag)
                        .frame(width: .spectre.control, height: .spectre.control)
                }
                .padding(.horizontal, -.spectre.margin)
            }
        }
    }
    .spectreStyle()
}
#endif
