//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import SwiftUI

struct Block: View {
    private var content: AnyView
    private var caption: AnyView?

    init(@ViewBuilder content: () -> some View, caption: (() -> some View)? = nil as (() -> EmptyView)?) {
        self.content = AnyView(content())
        self.caption = (caption?()).flatMap(AnyView.init)
    }

    var body: some View {
        VStack {
            self.content

            if let caption {
                Divider()

                caption
                    .foregroundStyle(Color.spectre.alternative)
                    .font(.spectre.caption1)
            }
        }
        .frame(width: .spectre.control * 2, height: .spectre.control * 2)
    }
}

#if DEBUG
#Preview {
    Block {
        Text("Content")
    } caption: {
        Text("Caption")
    }
    .spectreStyle()
}
#endif
