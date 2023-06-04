//
//  SpectreTipsView.swift
//  Spectre
//
//  Created by Maarten Billemont on 2023-04-25.
//  Copyright © 2023 Lyndir. All rights reserved.
//

import SwiftUI

struct SpectreTipsView: View {
    var body: some View {
        Text("Your identicon ╚☻╯⛄ helps you spot typos.")
            .foregroundColor(.spectre.secondary)
            .font(.spectre.caption2)
    }
}

struct SpectreTipsView_Previews: PreviewProvider {
    static var previews: some View {
        SpectreTipsView()
    }
}
