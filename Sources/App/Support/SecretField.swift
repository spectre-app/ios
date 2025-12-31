//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import SwiftUI

struct SecretField: View {
    let userName: String
    var userIdenticon: SpectreIdenticon?
    @Binding
    var keyFactory: SecretKeyFactory?
    var showStrength = false
    var namespace: Namespace.ID?

    @State
    private var secret = ""
    @State
    private var nameFormatter = PersonNameComponentsFormatter()
    @FocusState
    private var isFocused: Bool
    @Namespace
    private var privateNamespace
    @State
    private var secretIdenticon: SpectreIdenticon?
    @State
    private var strength: (ratio: Double, description: String)?

    var prompt: String {
        (self.nameFormatter.personNameComponents(from: self.userName)?.givenName).flatMap {
            "\($0)'s Spectre secret"
        } ?? "Your Spectre secret"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spectre.padding / 2) {
            HStack {
                SecureField(prompt: self.prompt, text: self.$secret)
                    .focused(self.$isFocused)
                    .submitLabel(.go)
                    .onChange(of: self.secret) {
                        self.keyFactory = SecretKeyFactory(userName: self.userName, userSecret: self.secret)
                    }

                Text(verbatim: (self.secretIdenticon ?? self.userIdenticon)?.text() ?? .init())
                    .foregroundColor(.spectre.alternative)
                    .font(.spectre.mono)
                    .matchedGeometryEffect(id: "identicon", in: self.namespace ?? self.privateNamespace, isSource: false)
            }
            .padding(.horizontal, .spectre.spacer)
            .frame(height: .spectre.control)
            .background {
                RoundedRectangle(cornerRadius: .infinity)
                    .fill(Color.spectre.backdrop)
            }
            .overlay {
                RoundedRectangle(cornerRadius: .infinity)
                    .stroke(lineWidth: 1)
                    .foregroundColor(.spectre.alternative)
            }
            .task(id: self.secret) {
                self.secretIdenticon = await self.secret.nonEmpty.flatMap { secret in
                    await Spectre.shared.identicon(userName: self.userName, userSecret: secret)
                }
                var strengthProgress: Double = .zero
                if let timeToCrack = Attacker.single.timeToCrack(string: self.secret.nonEmpty, hash: .spectre) {
                    strengthProgress = ((timeToCrack.period.seconds / age_of_the_universe) as NSDecimalNumber).doubleValue
                    strengthProgress = pow(1 - pow(min(1, strengthProgress) - 1, 30), 1 / 30.0)
                    self.strength = (strengthProgress, timeToCrack.period.normalize.localizedDescription)
                }
                else {
                    self.strength = (.zero, "Secret's defensive strength")
                }
            }

            if self.showStrength, let strength = self.strength {
                ProgressView(value: strength.ratio)
                    .padding(.horizontal, .spectre.margin)
                Label("\(strength.description)", systemImage: "shield.slash")
                    .font(.spectre.caption2)
                    .labelStyle(.spectre.with(axis: .horizontal))
                    .padding(.horizontal, .spectre.margin)
            }
        }
    }
}

#if DEBUG
#Preview {
    SecretField(userName: "Robert Lee Mitchell", keyFactory: .constant(nil), showStrength: true)
        .spectreStyle()
}
#endif
