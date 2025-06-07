//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import Observation
import SwiftUI

struct LoginScreen: View {
    @Observable
    class Model: MarshalObserver {
        var allUsers: [Marshal.UserFile] = []
        var phase: Phase = .switchingUser
        var isResettingSecret = false
        var isDeletingUser = false
        var users: [Marshal.UserFile] {
            SpectreModel.shared.autofill == nil
                ? self.allUsers
                : AppFeature.autofill.isEnabled ? self.allUsers.filter(\.autofill) : []
        }

        enum Phase: Hashable {
            case switchingUser
            case newUser
            case selectedUser(user: Marshal.UserFile)
            case authenticatingUserWithBiometrics(user: Marshal.UserFile, keyFactory: KeyFactory)
            case authenticatingUserWithSecret(user: Marshal.UserFile, secret: String = "")

            var selectedUser: Marshal.UserFile? {
                switch self {
                    case .switchingUser, .newUser: nil
                    case let .selectedUser(user): user
                    case let .authenticatingUserWithBiometrics(user: user, _): user
                    case let .authenticatingUserWithSecret(user: user, _): user
                }
            }
        }

        init(allUsers: [Marshal.UserFile]? = nil) {
            if let allUsers {
                self.allUsers = allUsers
            }
            else {
                Marshal.shared.observers.register(observer: self)
            }
            LeakRegistry.shared.register(self)
        }

        func didChange(userFiles: [Marshal.UserFile]) {
            DispatchQueue.main.async {
                self.allUsers = userFiles.sorted()

                if let user = self.phase.selectedUser, !self.allUsers.contains(user) {
                    self.phase = .switchingUser
                }
            }
        }
    }

    @State
    var model = Model()

    @EnvironmentObject
    private var config: AppConfig
    @Environment(\.reportMemoryLeaks)
    private var reportMemoryLeaks
    @Environment(\.spectre)
    private var spectre: SpectreModel
    @Environment(\.messages)
    private var messages: MessagesModel
    @State
    private var isSettingsPresented = false

    var body: some View {
        VStack {
            #if TARGET_APP
            if self.spectre.autofill == nil {
                SpectreTipsView()
            }
            #endif

            Group {
                switch self.model.phase {
                    case .switchingUser:
                        UsersListView(model: self.model)
                    case .newUser:
                        NewUserView(model: self.model)
                    case let .selectedUser(user),
                         let .authenticatingUserWithBiometrics(user, _),
                         let .authenticatingUserWithSecret(user, _):
                        SelectedUserView(model: self.model, selectedUser: user)
                }
            }
            .transition(.move(edge: .leading))
        }
        .safeAreaInset(edge: .bottom) {
            ControlGroup {
                if self.model.phase != .switchingUser {
                    Button("Switch User", systemImage: "filemenu.and.selection") {
                        withAnimation {
                            self.model.phase = .switchingUser
                        }
                    }
                }

                if let autofill = self.spectre.autofill {
                    if self.config.memoryProfiler {
                        Button("Report Leaks", systemImage: "pipe.and.drop.fill") {
                            self.reportMemoryLeaks()
                        }
                    }
                    Button("Cancel", systemImage: "xmark.octagon.fill") {
                        autofill.cancel(with: .init(.userCanceled))
                    }
                }
                else {
                    Button("Community", systemImage: "bubble.left.and.bubble.right.fill") {
                        self.messages.show(url: URL(string: "https://chat.spectre.app"))
                    }

                    Button("Settings", systemImage: "gearshape.2.fill") {
                        self.isSettingsPresented = true
                    }
                }
            }
            .controlGroupStyle(.spectre(alignment: .trailing))
            .padding(.spectre.margin)
        }
        .backgroundPreferenceValue(PhaseBackground.self) {
            $0?
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .foregroundColor(.spectre.mute)
                .ignoresSafeArea()
        }

        // Data
        .onChange(of: self.model.allUsers.isEmpty, initial: true) {
            if let autofill = self.spectre.autofill {
                if let identity = autofill.credentialRequest?.credentialIdentity.user,
                   let user = self.model.users.first(where: { $0.userName == identity }) {
                    self.model.phase = .selectedUser(user: user)
                }
            }
            else if let user = self.model.users.first {
                self.model.phase = .selectedUser(user: user)
            }
        }

        // Navigation
        #if TARGET_APP
        .popoverForm(isPresented: self.$isSettingsPresented) { SettingsScreen() }
        #endif
    }

    struct PhaseBackground: PreferenceKey {
        static func reduce(value: inout Image?, nextValue: () -> Image?) {
            value = nextValue() ?? value
        }
    }

    struct SelectedUserView: View {
        @Bindable
        var model: Model
        let selectedUser: Marshal.UserFile

        @Environment(\.spectre)
        private var spectre: SpectreModel
        @Environment(\.messages)
        private var messages: MessagesModel
        @EnvironmentObject
        private var config: AppConfig
        @FocusState
        private var isFocusOnSecret: Bool
        @Namespace
        private var namespace
        @State
        private var keychainKeyFactory: KeychainKeyFactory?

        var body: some View {
            Button {
                withAnimation {
                    switch self.model.phase {
                        case .selectedUser:
                            if let keychainKeyFactory {
                                self.model.phase = .authenticatingUserWithBiometrics(
                                    user: self.selectedUser, keyFactory: keychainKeyFactory
                                )
                            }
                            else {
                                self.model.phase = .authenticatingUserWithSecret(user: self.selectedUser)
                            }
                        default:
                            self.model.phase = .selectedUser(user: self.selectedUser)
                    }
                }
            } label: {
                VStack(alignment: .leading, spacing: .spectre.padding) {
                    Spacer()
                    Spacer()
                    Spacer()
                    Spacer()

                    Text(verbatim: self.selectedUser.identicon.text() ?? .init())
                        .foregroundColor(.spectre.alternative)
                        .font(.spectre.mono)
                        .matchedGeometryEffect(id: "identicon", in: self.namespace)

                    (
                        Text(verbatim: self.selectedUser.userName) +
                            Text("&nbsp;") + Text(self.selectedActionImage)
                    )
                    .fontWeight(.heavy)
                    .font(.spectre.largeTitle)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ControlGroup {
                        if case .authenticatingUserWithSecret = self.model.phase {
                            SecretField(
                                userName: self.selectedUser.userName,
                                identicon: self.selectedUser.identicon,
                                namespace: self.namespace
                            ) { secretKeyFactory in
                                Task {
                                    do {
                                        try await self.spectre.loginExistingUser(self.selectedUser, using: secretKeyFactory)
                                    }
                                    catch {
                                        err("Couldn't login", data: error)
                                    }
                                }
                            }
                            .focused(self.$isFocusOnSecret)
                            .onAppear {
                                self.isFocusOnSecret = true
                            }
                        }
                        else {
                            if let keyFactory = self.keychainKeyFactory {
                                Button("Skip \(type(of: keyFactory).factor)", systemImage: "character.cursor.ibeam") {
                                    withAnimation {
                                        self.model.phase = .authenticatingUserWithSecret(user: self.selectedUser)
                                    }
                                }
                            }

                            if self.spectre.autofill == nil {
                                Button("Reset Secret", systemImage: "eraser.line.dashed.fill") {
                                    withAnimation {
                                        self.model.isResettingSecret = true
                                    }
                                }
                                .alert(
                                    "Would you like Spectre to forget and change \(self.selectedUser.userName)'s secret?",
                                    isPresented: self.$model.isResettingSecret
                                ) {
                                    Button("Reset Secret", role: .destructive) {
                                        Task {
                                            try? await self.selectedUser.resetKey()
                                        }
                                    }
                                    Button("Cancel", role: .cancel) {}
                                } message: {
                                    Text("This will change all passwords for \(self.selectedUser.userName)'s sites.") +
                                        Text("\nReverting the change will also recover the original passwords.")
                                }

                                Button("Delete User", systemImage: "trash.fill") {
                                    withAnimation {
                                        self.model.isDeletingUser = true
                                    }
                                }
                                .alert(
                                    "Would you like Spectre to permanently remove and forget \(self.selectedUser.userName)?",
                                    isPresented: self.$model.isDeletingUser
                                ) {
                                    Button("Delete User", role: .destructive) {
                                        Task {
                                            try? await Marshal.shared.delete(userFile: self.selectedUser)
                                        }
                                    }
                                    Button("Cancel", role: .cancel) {}
                                } message: {
                                    Text("Recreating the user will also recover its generated passwords.") +
                                        Text("\nAny non-generated tokens will be lost.")
                                }
                            }
                        }
                    }
                    .controlGroupStyle(.spectre(alignment: .leading))

                    Spacer()
                }
                .padding(.horizontal, .spectre.margin)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .preference(key: PhaseBackground.self, value: Image(self.selectedUser.avatar.imageName))
            .onChange(of: self.selectedUser, initial: true) {
                if self.selectedUser.biometricLock, AppFeature.biometrics.isEnabled {
                    let keychainKeyFactory = KeychainKeyFactory(userName: self.selectedUser.userName, expiry: .minutes(5))
                    self.keychainKeyFactory = keychainKeyFactory.isKeyPresent(for: self.selectedUser.algorithm) ? keychainKeyFactory : nil
                }
                else {
                    self.keychainKeyFactory = nil
                }
            }
            .onChange(of: self.model.phase, initial: true) {
                if case let .authenticatingUserWithBiometrics(user, keyFactory) = self.model.phase {
                    Task {
                        try? await self.spectre.loginExistingUser(user, using: keyFactory)
                    }
                }
            }
        }

        var selectedActionImage: Image {
            switch self.model.phase {
                case .switchingUser, .newUser: Image(self.config.appIcon.glyphName)
                case .selectedUser: Image(systemName: "arrow.forward.circle")
                case .authenticatingUserWithBiometrics: Image(systemName: "faceid")
                case .authenticatingUserWithSecret: Image(systemName: "arrow.down.circle")
            }
        }
    }

    struct NewUserView: View {
        @Bindable
        var model: Model

        @State
        private var newUser: (avatar: User.Avatar, userName: String) = (.random(), "")

        @Environment(\.spectre)
        private var spectre: SpectreModel
        @FocusState
        private var isFocusOnUserName: Bool
        @FocusState
        private var isFocusOnSecret: Bool

        var body: some View {
            VStack(alignment: .leading, spacing: .spectre.padding) {
                Spacer()

                Spacer()

                HStack {
                    Button("Previous Avatar", systemImage: "arrow.backward.circle") {
                        withAnimation {
                            self.newUser.avatar.previous()
                        }
                    }

                    Spacer()

                    Button("Switch User", systemImage: "filemenu.and.selection") {
                        withAnimation {
                            self.model.phase = .switchingUser
                        }
                    }

                    Spacer()

                    Button("Next Avatar", systemImage: "arrow.forward.circle") {
                        withAnimation {
                            self.newUser.avatar.next()
                        }
                    }
                }

                Spacer()

                TextField(prompt: "Your full name", text: self.$newUser.userName)
                    .textContentType(.name)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .fontWeight(.heavy)
                    .font(.spectre.largeTitle)
                    .modify {
                        $0
                        #if canImport(UIKit)
                        .textInputAutocapitalization(.words)
                        .keyboardType(.alphabet)
                        #endif
                    }
                    .focused(self.$isFocusOnUserName)
                    .onSubmit { self.isFocusOnSecret = true }

                SecretField(userName: self.newUser.userName, showStrength: true) { keyFactory in
                    Task {
                        let newUser = try await self.spectre.loginNewUser(using: keyFactory)
                        newUser.avatar = self.newUser.avatar
                        if let newUser = try Marshal.UserFile(user: newUser) {
                            self.model.phase = .selectedUser(user: newUser)
                        }
                        else {
                            self.model.phase = .switchingUser
                        }
                    }
                }
                .focused(self.$isFocusOnSecret)

                Spacer()
            }
            .padding(.horizontal, .spectre.margin)
            .onAppear {
                self.isFocusOnUserName = true
            }
            .preference(key: PhaseBackground.self, value: Image(self.newUser.avatar.imageName))
        }
    }

    struct UsersListView: View {
        @Bindable
        var model: Model

        @Environment(\.spectre)
        private var spectre: SpectreModel
        @Environment(\.messages)
        private var messages: MessagesModel
        @EnvironmentObject
        private var config: AppConfig

        private func isPreferred(user: Marshal.UserFile) -> Bool {
            guard let autofill = self.spectre.autofill
            else { return false }

            return autofill.credentialRequest?.credentialIdentity.user == user.userName
        }

        var body: some View {
            List {
                Section("Spectre Users") {
                    if self.spectre.autofill?.isRequestingCredentials ?? true {
                        // App or Auto-Fill a credential.
                        ForEach(self.model.users) { user in
                            Button {
                                withAnimation {
                                    self.model.phase = .selectedUser(user: user)
                                }
                            } label: {
                                Text(verbatim: user.userName)

                                (
                                    Text("\(user.lastUsed, format: .dateTime)") +
                                        Text("&nbsp;—&nbsp;") +
                                        Text(
                                            (user.biometricLock ? KeychainKeyFactory.factor.iconName : nil)
                                                .flatMap(Image.init(systemName:)) ?? Image(systemName: "character.cursor.ibeam")
                                        )
                                )
                                .font(.spectre.caption1)
                                .foregroundStyle(Color.spectre.alternative)

                                if let origin = user.origin,
                                   self.model.allUsers.count(where: { $0.userName == user.userName }) > 1 {
                                    Text(verbatim: origin.lastPathComponent)
                                        .font(.spectre.caption2)
                                        .foregroundStyle(Color.spectre.alternative)
                                }
                            }
                            .buttonStyle(.spectreBox(alignment: .leading, image: Image(user.avatar.imageName)) {
                                Color.spectre.selection
                                    .blur(radius: .spectre.margin)
                                    .background(ContainerRelativeShape().stroke(Color.spectre.tint))
                                    .opacity(self.isPreferred(user: user) ? .on : .off)
                            })
                        }
                    }

                    if let autofill = self.spectre.autofill {
                        if !AppFeature.autofill.isEnabled {
                            // Auto-Fill is not enabled.
                            Image(self.config.appIcon.glyphName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: .spectre.shape)
                            Text("Spectre")
                                .font(.spectre.largeTitle)
                            Divider()
                            Text("""
                                To begin using auto-fill, open the Spectre app and activate your subscription.
                                """)
                            .font(.spectre.body)
                        }
                        else if self.model.users.isEmpty || !autofill.isRequestingCredentials {
                            // Auto-Fill with no user selection.
                            Image(self.config.appIcon.glyphName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: .spectre.shape)
                            Text("Spectre")
                                .font(.spectre.largeTitle)
                            Divider()
                            Text("""
                                The following Spectre users have enabled auto-fill.
                                To change a user's participation, log into the user from the Spectre app \
                                and toggle their ⦗AutoFill⦘ preference.
                                """)
                            .font(.spectre.body)

                            ForEach(self.model.allUsers) { user in
                                Toggle(user.userName, isOn: .constant(self.model.users.map(\.id).contains(user.id)))
                                    .toggleStyle(.spectreBox())
                            }
                        }
                    }
                    else {
                        // App.
                        Button {
                            withAnimation {
                                self.model.phase = .newUser
                            }
                        } label: {
                            Text("New User")
                            Text("Add a new user to create passwords for.")
                                .font(.spectre.caption1)
                                .foregroundStyle(Color.spectre.alternative)
                        }
                        .buttonStyle(.spectreBox(alignment: .trailing) {
                            Image(self.config.appIcon.glyphName)
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding(-.spectre.margin)
                        })

                        if AppFeature.incognito.isEnabled {
                            Button {
                                Task {
                                    let keyFactory = try await self.messages.promptAuthentication(to: "Incognito sign-in", action: "Log in")
                                    try await self.spectre.loginIncognitoUser(using: keyFactory)
                                }
                            } label: {
                                Text("Incognito")
                                Text("Log into a user without leaving a trace.")
                                    .font(.spectre.caption1)
                                    .foregroundStyle(Color.spectre.alternative)
                            }
                            .buttonStyle(.spectreBox(alignment: .trailing) {
                                Image(systemName: "person.crop.rectangle.stack.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .aspectRatio(1, contentMode: .fit)
                            })
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .font(.spectre.headline)
            .listStyle(.plain)
            .multilineTextAlignment(.leading)
        }
    }
}

import AuthenticationServices

#if DEBUG
#Preview {
    LoginScreen(model: .init(allUsers: [
        Marshal.UserFile(
            format: .default, exportDate: Date(), redacted: true, algorithm: .current, avatar: .avatar_3,
            userName: "Robert Lee Mitchell", identicon: .from("╚☻╯⛄", color: .green)!,
            userKeyID: .init(), lastUsed: Date(), biometricLock: true, autofill: true
        ),
        Marshal.UserFile(
            format: .default, exportDate: Date(), redacted: true, algorithm: .current, avatar: .avatar_10,
            userName: "Katherine Johnson", identicon: .from("╚▒╯⛄", color: .blue)!,
            userKeyID: .init(), lastUsed: Date(), biometricLock: false, autofill: true
        ),
        Marshal.UserFile(
            format: .default, exportDate: Date(), redacted: true, algorithm: .current, avatar: .avatar_8,
            userName: "Mary Jackson", identicon: .from("═☻╝☔", color: .yellow)!,
            userKeyID: .init(), lastUsed: Date(), biometricLock: false, autofill: false
        ),
        Marshal.UserFile(
            format: .default, exportDate: Date(), redacted: true, algorithm: .current, avatar: .avatar_9,
            userName: "Dorothy Vaughan", identicon: .from("═☻╝☔", color: .yellow)!,
            userKeyID: .init(), lastUsed: Date(), biometricLock: true, autofill: false
        ),
        Marshal.UserFile(
            format: .default, exportDate: Date(), redacted: true, algorithm: .current, avatar: .avatar_7,
            userName: "Valentina Tereshkova", identicon: .from("═☻╝☔", color: .yellow)!,
            userKeyID: .init(), lastUsed: Date(), biometricLock: false, autofill: false
        ),
        Marshal.UserFile(
            format: .default, exportDate: Date(), redacted: true, algorithm: .current, avatar: .avatar_6,
            userName: "Alan Shepard", identicon: .from("═☻╝☔", color: .yellow)!,
            userKeyID: .init(), lastUsed: Date(), biometricLock: true, autofill: false
        ),
        Marshal.UserFile(
            format: .default, exportDate: Date(), redacted: true, algorithm: .current, avatar: .avatar_5,
            userName: "Yuri Gagarin", identicon: .from("═☻╝☔", color: .yellow)!,
            userKeyID: .init(), lastUsed: Date(), biometricLock: false, autofill: false
        ),
        Marshal.UserFile(
            format: .default, exportDate: Date(), redacted: true, algorithm: .current, avatar: .avatar_1,
            userName: "John Glenn", identicon: .from("═☻╝☔", color: .yellow)!,
            userKeyID: .init(), lastUsed: Date(), biometricLock: false, autofill: false
        ),
        Marshal.UserFile(
            format: .default, exportDate: Date(), redacted: true, algorithm: .current, avatar: .avatar_13,
            userName: "Eileen Collins", identicon: .from("═☻╝☔", color: .yellow)!,
            userKeyID: .init(), lastUsed: Date(), biometricLock: false, autofill: false
        ),
    ]))
    .spectreStyle()
    .environment(\.spectre, using(.shared) {
        $0.autofill = .init(credentialRequest: ASPasswordCredentialRequest(credentialIdentity: .init(
            serviceIdentifier: ASCredentialServiceIdentifier(identifier: "spectre.app", type: .domain),
            user: "Robert Lee Mitchell", recordIdentifier: nil
        )))
    })
}
#endif
