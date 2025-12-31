//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import AuthenticationServices
import SwiftUI

struct AutoFillSetupScreen: View {
    @Bindable
    var user: User

    @State
    private var loginName = ""
    @FocusState
    private var isLoginNameFocused: Bool
    @State
    private var isAutoFillEnabled = false

    var body: some View {
        Form {
            Pager(content: [
                self.introItem,
                self.biometricItem,
                self.loginItem,
                self.systemItem,
                self.userItem,
            ])
        }
        .toggleStyle(.spectreBox())
        .presentationDetents([.medium])
        .task(id: self.user.loginState) {
            self.loginName = await (try? self.user.result(keyPurpose: .identification)?.task.value) ?? ""
        }
        .onChange(of: self.loginName) {
            if let operation = self.user.state(keyPurpose: .identification, resultParam: self.loginName) {
                Task {
                    self.user.loginState = try await operation.task.value
                }
            }
        }
        .onAppear {
            Task {
                // TODO: needs update on return from settings?
                self.isAutoFillEnabled = await ASCredentialIdentityStore.shared.state().isEnabled
            }
        }
    }

    var introItem: Pager.PagerItem {
        Pager.PagerItem(
            title: "Turning On AutoFill", systemImage: "signpost.right",
            isDone: true,
        ) {
            Text(
                """
                To get AutoFill working smoothly on your \(AppConfig.shared.model), there are a few things we need to get done.
                """,
            )
            Text(
                """
                Swipe ahead to begin.
                """,
            )
        }
    }

    var biometricItem: Pager.PagerItem {
        Pager.PagerItem(
            title: "Biometric Lock", systemImage: KeychainKeyFactory.factor.iconName ?? "touchid",
            isDone: self.user.biometricLock,
        ) {
            Text(
                """
                Consider turning on \(KeychainKeyFactory.factor.description) as the quickest way to unlock your passwords.
                """,
            )
            Toggle("Biometric Lock", systemImage: KeychainKeyFactory.factor.iconName ?? "touchid", isOn: self.$user.biometricLock)
        }
    }

    var loginItem: Pager.PagerItem {
        Pager.PagerItem(
            title: "Standard Login", systemImage: "person.crop.rectangle",
            isDone: !self.loginName.isEmpty,
        ) {
            Text(
                """
                Set the login name you use for most sites.
                To save an e-mail address, first select ⦗\(SpectreResultType.statePersonal.description)⦘.
                """,
            )
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
                .submitLabel(.done)
                .textContentType(.emailAddress)
                .autocorrectionDisabled()
                .focused(self.$isLoginNameFocused)
                .disabled(!self.user.loginType.in(class: .stateful))
                .modify {
                    $0
                    #if canImport(UIKit)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    #endif
                }
            Text("You can also add site-specific logins to individual sites.")
                .font(.spectre.caption1)
        }
    }

    var systemItem: Pager.PagerItem {
        Pager.PagerItem(
            title: "\(AppConfig.shared.model) Settings", systemImage: "gear.badge.checkmark",
            isDone: self.isAutoFillEnabled,
        ) {
            Text(
                """
                To enable AutoFill on your \(AppConfig.shared.model):
                ❶ Open ⦗Settings⦘ ❯ ⦗General⦘
                ❷ Find ⦗AutoFill & Passwords⦘
                ❸ Enable ⦗AutoFill From⦘ for ⦗\(productName)⦘
                """,
            )
            Toggle("AutoFill in \(AppConfig.shared.model) Settings", systemImage: "keyboard", isOn: self.$isAutoFillEnabled)
                .allowsHitTesting(false)
                .overlay {
                    Button {
                        Task {
                            #if canImport(UIKit)
                            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                await UIApplication.shared.open(settingsURL)
                            }
                            #else
                            // TODO: macOS
                            #endif
                        }
                    } label: {
                        Color.spectre.placeholder.opacity(0.1) /* FIXME: */
                    }
                    .buttonStyle(.plain)
                }
        }
    }

    var userItem: Pager.PagerItem {
        Pager.PagerItem(
            title: "\(self.user.userName)", systemImage: "keyboard",
            isDone: self.user.autofill,
        ) {
            Text(
                """
                Show auto-fill suggestions for \(self.user.userName)'s sites from other apps.
                """,
            )
            Toggle("AutoFill for \(self.user.userName)", systemImage: "keyboard", isOn: self.$user.autofill)
        }
    }
}

#if DEBUG
#Preview {
    Path().popoverForm(isPresented: .constant(true)) {
        AutoFillSetupScreen(
            user: User(avatar: .avatar_3, userName: "Robert Lee Mitchell"),
        )
    }
    .spectreStyle()
}
#endif
