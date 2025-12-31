//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import SwiftUI

public struct Pager: View {
    var content: [PagerItem]
    @State
    private var scroll: CGFloat = .zero
    @State
    private var width: CGFloat = .zero
    private var itemWidth: CGFloat? {
        self.width.nonEmpty.flatMap { width in
            (width - .spectre.margin * 2 - .spectre.padding * CGFloat(self.content.count - 1))
                / CGFloat(self.content.count)
        }
    }

    public var body: some View {
        ScrollViewReader { _ in
            ScrollView(.horizontal) {
                HStack(spacing: .spectre.padding) {
                    ForEach(self.content) {
                        $0
                            .padding(.top, .spectre.padding)
                            .padding(.horizontal, .spectre.margin)
                            .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
                .onGeometryChange(for: CGRect.self) {
                    $0.frame(in: .named("pager"))
                } action: { self.scroll = -$0.origin.x / ($0.size.width - self.width) }
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .coordinateSpace(name: "pager")
            .onGeometryChange(for: CGFloat.self) {
                $0.frame(in: .local).size.width
            } action: { self.width = $0 }
            .background(alignment: .top) {
                Color.spectre.placeholder
                    .background(alignment: .leading) {
                        Rectangle()
                            .frame(width: self.itemWidth)
                            .padding(.leading, self.scroll * (self.width - .spectre.margin * 2 - (self.itemWidth ?? .zero)))
                    }
                    .mask {
                        HStack(spacing: .spectre.padding) {
                            ForEach(self.content) { page in
                                ZStack(alignment: .bottomTrailing) {
                                    RoundedRectangle(cornerRadius: .infinity)
                                        .frame(height: .spectre.padding)
                                        .frame(maxHeight: .infinity, alignment: .bottom)
                                    if page.isDone {
                                        Image(systemName: "checkmark")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .padding(.bottom, .spectre.padding)
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: .spectre.margin)
                    .padding(.top, .spectre.padding + .spectre.shape / 2 + .spectre.padding)
                    .padding(.horizontal, .spectre.margin)
            }
        }
        .padding(.horizontal, -.spectre.margin)
    }

    public struct PagerItem: View, Identifiable {
        private let title: String
        private var systemImage: String?
        fileprivate var isDone: Bool
        private var content: () -> AnyView

        public init(
            title: String, systemImage: String? = nil, isDone: Bool = false,
            @ViewBuilder content: @escaping () -> some View
        ) {
            self.title = title
            self.systemImage = systemImage
            self.isDone = isDone
            self.content = { AnyView(content()) }
        }

        public var id: String { self.title }
        public var body: some View {
            VStack(alignment: .leading, spacing: .spectre.padding) {
                Image(systemName: self.systemImage ?? "")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .frame(height: .spectre.shape / 2)
                    .opacity(.short)

                Path().frame(height: .spectre.margin)

                Text(self.title)
                    .font(.spectre.headline)

                self.content()

                Spacer()
            }
        }
    }
}

#if DEBUG
#Preview {
    Pager(content: [
        .init(title: "text") {
            Text("content")
        },
        .init(title: "done", isDone: true) {
            Text("content")
        },
        .init(title: "image", systemImage: "face.smiling") {
            Text("content")
        },
    ])
    .spectreStyle()
}
#endif
