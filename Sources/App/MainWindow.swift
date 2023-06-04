//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import SwiftUI

struct MainWindow: View {
    @Environment(\.spectre)
    private var spectre: SpectreModel

    var body: some View {
        ZStack {
            if let activeUser = self.spectre.activeUser {
                SitesScreen(user: activeUser)
                    .transition(.slide)
                    .zIndex(1)
            }
            else {
                LoginScreen()
                    .transition(.opacity)
                    .zIndex(0)
            }
        }
    }
}
