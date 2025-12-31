//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import SwiftUI

struct UserEditScreen: View {
    @Bindable var user: User

    @Environment(\.messages)
    private var messages: MessagesModel
    @State
    private var loginName = ""
    @FocusState
    private var isLoginNameFocused: Bool
    @State
    private var authenticatedIdentifier = ""
    @State
    private var algorithm: SpectreAlgorithm?
    @State
    private var secret = ""
    @State
    private var isAutofillDecisionShown = false

    var body: some View {
        Form {
            self.editUser
            self.editDefaultTypes
            self.editFeatures
            self.editDetails
        }
        .popoverTitle(self.user.userName)
        .task(id: String(reflecting: type(of: self.user.userKeyFactory))) {
            self.authenticatedIdentifier = await (try? self.user.authenticatedIdentifier) ?? ""
        }
        .task(id: self.user.loginState) {
            self.loginName = await (try? self.user.result(keyPurpose: .identification)?.task.value) ?? ""
        }
        .onChange(of: self.loginName) {
            if AppFeature.logins.isEnabled, let operation = self.user.state(keyPurpose: .identification, resultParam: self.loginName) {
                Task {
                    self.user.loginState = try await operation.task.value
                }
            }
        }
    }

    @ViewBuilder
    var editUser: some View {
        Section {
            Text(verbatim: (self.user).identicon.text() ?? "unset")
                .font(.spectre.largeTitle)
                .frame(maxWidth: .infinity, alignment: .trailing)

            GroupBox("Avatar") {
                Carousel(values: User.Avatar.allCases, selection: self.$user.avatar) {
                    Image($0.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: .spectre.shape, height: .spectre.shape)
                }
                .padding(.horizontal, -.spectre.margin)
            }

            ControlGroup {
                Button("Export") { /* TODO: */  }
                Button("Settings") { /* TODO: */  }
                Button("Log Out") { /* TODO: */  }
            }
        }
    }

    @ViewBuilder
    var editDefaultTypes: some View {
        Section("Sites") {
            StoreContent(feature: .logins) {
                GroupBox("Login") {
                    Carousel(
                        values: [SpectreResultType].joined(
                            [.statePersonal],
                            SpectreResultType.recommendedTypes[.identification],
                            SpectreResultType.allCases.filter { !$0.has(feature: .alternate) },
                        ).unique(), selection: self.$user.loginType,
                    ) { type in
                        Block {
                            Text(verbatim: type.description)
                        } caption: {
                            Text(verbatim: type.class?.description ?? "")
                        }
                    }
                    .onChange(of: self.user.loginType) {
                        if self.user.loginType.class == .stateful {
                            self.isLoginNameFocused = true
                        }
                    }

                    TextField(prompt: "Your default login", text: self.$loginName)
                        .focused(self.$isLoginNameFocused)
                        .disabled(!self.user.loginType.in(class: .stateful))
                        .submitLabel(.done)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .modify {
                            $0
                            #if canImport(UIKit)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            #endif
                        }

                    Text(
                        """
                        The login name to use for sites that have no site-specific name. \
                        Typically this is your e-mail address.
                        """,
                    )
                    .font(.caption)
                }
            }

            GroupBox("Password") {
                Carousel(
                    values: [SpectreResultType].joined(
                        SpectreResultType.recommendedTypes[.authentication],
                        [SpectreResultType.statePersonal],
                        SpectreResultType.allCases.filter { !$0.has(feature: .alternate) },
                    ).unique(), selection: self.$user.resultType,
                ) { type in
                    Block {
                        Text(verbatim: type.description)
                    } caption: {
                        Text(verbatim: type.class?.description ?? "")
                    }
                }
                .padding(.horizontal, -.spectre.margin)

                Text("The password type to use for new sites.")
                    .font(.caption)
            }

            StoreContent(feature: .strength) {
                GroupBox("Defense Strategy") {
                    Carousel(values: Attacker.allCases, selection: (self.$user.attacker).nonEmpty(default: .default)) { attacker in
                        Block {
                            let cost = attacker.fixed_budget + attacker.monthly_budget * 12
                            Text("\(number: cost, decimals: 0 ... 0, locale: .C, .currency, .abbreviated)")
                        } caption: {
                            Text(attacker.description)
                        }
                    }
                    .padding(.horizontal, -.spectre.margin)

                    Text(
                        "Yearly budget of the primary attacker persona you're seeking to repel (@ \((self.user.attacker?.rig.cost_per_kwh ?? .zero).formatted())$/kWh).",
                    )
                    .font(.caption)
                }
            }
        }
    }

    @ViewBuilder
    var editFeatures: some View {
        Section("Preferences") {
            LabeledContent(
                """
                Do not reveal passwords on screen.
                Useful to deter screen snooping.
                """,
            ) {
                Toggle("Mask Passwords", systemImage: "eye", isOn: self.$user.maskPasswords)
            }

            StoreContent(feature: .biometrics) {
                LabeledContent(
                    """
                    Sign in using biometrics (eg. TouchID, FaceID).
                    Saves your user key in the device's key chain.
                    """,
                ) {
                    Toggle("Biometric Lock", systemImage: KeychainKeyFactory.factor.iconName ?? "touchid", isOn: self.$user.biometricLock)
                }
            }

            StoreContent(feature: .autofill) {
                LabeledContent(
                    """
                    Auto-fill your site passwords from other apps.
                    """,
                ) {
                    Toggle("AutoFill", systemImage: "keyboard", isOn: self.$user.autofill)
                }
            }
            .onChange(of: [self.user.autofill, self.user.autofillDecided], initial: true) {
                if self.user.autofill, !self.user.autofillDecided {
                    self.isAutofillDecisionShown = true
                }
            }
            .popoverForm(isPresented: self.$isAutofillDecisionShown) {
                AutoFillSetupScreen(user: self.user)
            }

            StoreContent(feature: .sharing) {
                LabeledContent(
                    """
                    Allow other apps to see and backup your user through On My iPhone.
                    """,
                ) {
                    Toggle("File Sharing", systemImage: "point.3.connected.trianglepath.dotted", isOn: self.$user.sharing)
                }
            }
        }
        .labeledContentStyle(.spectreCaptioned)
        .multilineTextAlignment(.leading)
    }

    @ViewBuilder
    var editDetails: some View {
        Section("Details") {
            Picker(selection: self.$algorithm.nonEmpty(default: self.user.algorithm)) {
                ForEach(SpectreAlgorithm.allCases) { type in
                    Text(type.localizedDescription)
                }
            } label: {
                Text("Algorithm")
            }
            .foregroundColor(self.user.algorithm != .current ? .red : nil)
            .alert(
                "\(self.algorithm ?? .current < self.user.algorithm ? "Downgrade" : "Upgrade") your Spectre user",
                isPresented: self.$algorithm.isSet(), presenting: self.algorithm,
            ) { (algorithm: SpectreAlgorithm) in
                SecureField(prompt: "Enter your Spectre secret to confirm", text: self.$secret)
                Button("Cancel", role: .cancel) {
                    self.secret = ""
                }
                Button(algorithm < self.user.algorithm ? "Downgrade" : "Upgrade") {
                    Task {
                        defer { self.secret = "" }

                        do {
                            let keyFactory = SecretKeyFactory(userName: self.user.userName, userSecret: self.secret)
                            var key = try await keyFactory.getKey(for: self.user.algorithm)
                            if try !key.matches(keyID: self.user.userKeyID) {
                                throw AppError.issue("Incorrect Spectre secret for \(self.user.userName)")
                            }

                            key = try await keyFactory.getKey(for: algorithm)
                            self.user.identicon = keyFactory.metadata.identicon
                            self.user.algorithm = key.algorithm
                            self.user.userKeyID = key.keyID
                        }
                        catch {
                            err("Couldn't \(algorithm < self.user.algorithm ? "downgrade" : "upgrade") user", data: error)
                        }
                    }
                }
            } message: {
                Text(
                    "Your Spectre user algorithm will be \(self.algorithm ?? .current < self.user.algorithm ? "downgraded" : "upgraded") to \($0.localizedDescription).",
                )
            }

            LabeledContent("Sites") {
                Text("^[\(self.user.sites.count) sites](inflect: true)")
                    .font(.spectre.callout)
            }

            LabeledContent("Last use") {
                Text(self.user.lastUsed.formatted())
                    .font(.spectre.callout)
            }

            LabeledContent(self.authenticatedIdentifier) {
                Button("Copy Anonymous User Identifier") {
                    #if canImport(UIKit)
                    UIPasteboard.general.setObjects(
                        [self.authenticatedIdentifier as NSString],
                        localOnly: AppFeature.handoff.isEnabled, expirationDate: nil,
                    )
                    #elseif canImport(AppKit)
                    // TODO: macOS
                    #endif
                }
            }
            .labeledContentStyle(.spectreCaptioned)
        }
    }
}

#if DEBUG
#Preview {
    let user = User(avatar: .avatar_3, userName: "Robert Lee Mitchell")
    Path().popoverForm(isPresented: .constant(true)) {
        UserEditScreen(user: user)
            .task {
                _ = try? await user.login(
                    using: SecretKeyFactory(userName: user.userName, userSecret: "banana duckling"),
                )
            }
    }
    .spectreStyle()
}
#endif
