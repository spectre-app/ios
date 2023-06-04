//
//  LoginScreen.swift
//  Spectre
//
//  Created by Maarten Billemont on 2023-03-05.
//  Copyright © 2023 Lyndir. All rights reserved.
//

import Observation
import SwiftUI

struct LoginScreen: View {
    @Observable class Model: MarshalObserver {
        var users: [Marshal.UserFile] = []
        var phase: Phase = .switchingUser
        var isResettingSecret = false
        var isDeletingUser = false
        var secretText: String = ""

        enum Phase: Hashable {
            case switchingUser
            case newUser
            case selectedUser(user: Marshal.UserFile)
            case authenticatingUserWithBiometrics(user: Marshal.UserFile)
            case authenticatingUserWithSecret(user: Marshal.UserFile, secret: String)

            var selectedUser: Marshal.UserFile? {
                switch self {
                    case .switchingUser, .newUser: return nil
                    case let .selectedUser(user): return user
                    case let .authenticatingUserWithBiometrics(user: user): return user
                    case let .authenticatingUserWithSecret(user: user, _): return user
                }
            }
        }

        init() {
            Marshal.shared.observers.register(observer: self)
        }

        func didChange(userFiles: [Marshal.UserFile]) {
            users = userFiles.sorted()

            if let user = phase.selectedUser, !self.users.contains([user]) {
                phase = .switchingUser
            }
        }
    }

    var model = Model()
    var body: some View {
        VStack {
            SpectreTipsView()

            Group {
                if let selectedUser = self.model.phase.selectedUser {
                    SelectedUserView(model: self.model, selectedUser: selectedUser)
                } else if case .newUser = self.model.phase {
                    NewUserView(model: self.model)
                } else {
                    UsersListView(model: self.model)
                }
            }
            .transition(.move(edge: .leading))

            Button(self.model.phase == .switchingUser ? "Add new user" : "Switch user") {
                withAnimation {
                    if self.model.phase == .switchingUser {
                        self.model.phase = .newUser
                    } else {
                        self.model.phase = .switchingUser
                    }
                }
            }
            .font(.spectre.callout)

            ToolbarView()
        }
        .backgroundPreferenceValue(PhaseBackground.self) {
            $0?
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .foregroundColor(.spectre.mute)
                .ignoresSafeArea()
        }
        .background()

        // Data
        .onChange(of: self.model.phase) {
            self.model.secretText = ""
        }
        .onAppear {
            self.model.phase = self.model.users.first.flatMap { .selectedUser(user: $0) } ?? .switchingUser
        }
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
        @FocusState
        private var isFocusOnSecret: Bool
        @Namespace
        private var namespace

        var body: some View {
            Button {
                withAnimation {
                    switch self.model.phase {
                        case .selectedUser:
                            self.model.phase = self.selectedUser.biometricLock ?
                                .authenticatingUserWithBiometrics(user: self.selectedUser) :
                                .authenticatingUserWithSecret(user: self.selectedUser, secret: "")
                        default:
                            self.model.phase = .selectedUser(user: self.selectedUser)
                    }
                }
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Spacer()
                    Spacer()
                    Spacer()
                    Spacer()

                    (Text(verbatim: selectedUser.userName) +
                     Text("&nbsp;\(self.selectedActionImage)"))
                    .fontWeight(.heavy)
                    .font(.spectre.largeTitle)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if case .authenticatingUserWithSecret = self.model.phase {
                        SecretField(
                            userName: self.selectedUser.userName,
                            identicon: self.selectedUser.identicon,
                            secret: self.$model.secretText,
                            namespace: self.namespace
                        ) { keyFactory in
                            Task {
                                try? await self.spectre.loginExistingUser(self.selectedUser, using: keyFactory)
                            }
                        }
                        .focused(self.$isFocusOnSecret)
                        .onAppear {
                            self.isFocusOnSecret = true
                        }
                    } else if case .selectedUser = self.model.phase {
                        ControlGroup {
                            Text(verbatim: self.selectedUser.identicon.text() ?? .init())
                                .foregroundColor(.spectre.secondary)
                                .font(.spectre.mono)
                                .matchedGeometryEffect(id: "identicon", in: self.namespace)

                            Button("Forget Secret", systemImage: "eraser.line.dashed") {
                                withAnimation {
                                    self.model.isResettingSecret = true
                                }
                            }
                            .alert("Would you like Spectre to forget and reset \(selectedUser.userName)'s secret?", isPresented: self.$model.isResettingSecret) {
                                Button("Reset Secret", role: .destructive) {
                                    Task {
                                        try? await self.selectedUser.resetKey()
                                    }
                                }
                                Button("Cancel", role: .cancel) {}
                            } message: {
                                Text("This will change all passwords for \(selectedUser.userName)'s sites.") +
                                Text("\nReverting the change will also recover the original passwords.")
                            }

                            Button("Delete", systemImage: "trash") {
                                withAnimation {
                                    self.model.isDeletingUser = true
                                }
                            }
                            .alert("Would you like Spectre to permanently remove and forget \(selectedUser.userName)?", isPresented: self.$model.isDeletingUser) {
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

                            if self.selectedUser.biometricLock {
                                Button("Enter Secret", systemImage: "character.cursor.ibeam") {
                                    withAnimation {
                                        self.model.phase = .authenticatingUserWithSecret(user: self.selectedUser, secret: "")
                                    }
                                }
                            }
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .buttonStyle(.plain)
            .preference(key: PhaseBackground.self, value: self.selectedUser.avatar.image.flatMap(Image.init))
        }

        var selectedActionImage: Image {
            switch model.phase {
                case .switchingUser, .newUser: return Image("")
                case .selectedUser: return Image(systemName: "arrow.forward.circle.fill")
                case .authenticatingUserWithBiometrics: return Image(systemName: "faceid")
                case .authenticatingUserWithSecret: return Image(systemName: "arrow.down.circle.fill")
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
            Button {
                withAnimation {}
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Spacer()

                    Spacer()

                    HStack {
                        Button("Previous Avatar", systemImage: "arrow.backward.circle") {
                            self.newUser.avatar.previous()
                        }

                        Spacer()

                        Button("Next Avatar", systemImage: "arrow.forward.circle") {
                            self.newUser.avatar.next()
                        }
                    }

                    Spacer()

                    TextField("Full name", text: self.$newUser.userName, prompt: Text("Your full name"))
                        .focused(self.$isFocusOnUserName)
                        .submitLabel(.next)
                        .onSubmit { self.isFocusOnSecret = true }
                        .fontWeight(.heavy)
                        .font(.spectre.largeTitle)

                    SecretField(
                        userName: self.newUser.userName,
                        secret: self.$model.secretText
                    ) { keyFactory in
                        Task {
                            try? await self.spectre.loginNewUser(using: keyFactory)
                            self.spectre.activeUser?.avatar = self.newUser.avatar
                        }
                    }
                    .focused(self.$isFocusOnSecret)

                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .onAppear {
                self.isFocusOnUserName = true
            }
            .preference(key: PhaseBackground.self, value: self.newUser.avatar.image.flatMap(Image.init))
        }
    }

    struct UsersListView: View {
        @Bindable
        var model: Model

        var body: some View {
            List {
                ForEach(self.model.users) { user in
                    Button {
                        withAnimation {
                            self.model.phase = .selectedUser(user: user)
                        }
                    } label: {
                        GroupBox {
                            HStack {
                                (user.avatar.image).flatMap(Image.init)?
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .padding(.top, 12)
                                    .frame(width: 44, height: 44)
                                    .background(Color.spectre.panel)
                                    .mask(RoundedRectangle(cornerRadius: 8))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color.spectre.secondary, lineWidth: 1)
                                    }

                                Text(user.userName)
                                    .fontWeight(user == self.model.phase.selectedUser ? .heavy : nil)
                                    .font(.spectre.callout)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Spacer(minLength: .zero)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .multilineTextAlignment(.leading)
            .preference(key: PhaseBackground.self, value: Image(.logo))
        }
    }

    struct SecretField: View {
        let userName: String
        var identicon: SpectreIdenticon?
        @Binding
        var secret: String
        var namespace: Namespace.ID?
        let authenticate: (KeyFactory) -> Void

        @State
        private var nameFormatter = PersonNameComponentsFormatter()
        @FocusState
        private var isFocused: Bool
        @Namespace
        private var privateNamespace
        @State
        private var secretIdenticon: SpectreIdenticon?

        var prompt: String {
            (nameFormatter.personNameComponents(from: userName)?.givenName).flatMap {
                "\($0)'s Spectre secret"
            } ?? "Your Spectre secret"
        }

        var body: some View {
            HStack {
                SecureField("Spectre secret", text: self.$secret, prompt: Text(self.prompt))
                    .focused(self.$isFocused)
                    .submitLabel(.go)
                    .onSubmit {
                        self.authenticate(
                            SecretKeyFactory(userName: self.userName, userSecret: self.secret)
                        )
                    }

                Text(verbatim: (self.secretIdenticon ?? self.identicon)?.text() ?? .init())
                    .foregroundColor(.spectre.secondary)
                    .font(.spectre.mono)
                    .matchedGeometryEffect(id: "identicon", in: self.namespace ?? self.privateNamespace)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background {
                if self.isFocused {
                    RoundedRectangle(cornerRadius: .infinity)
                        .fill(Color.spectre.backdrop)
                    RoundedRectangle(cornerRadius: .infinity)
                        .stroke(lineWidth: 1)
                        .foregroundColor(.spectre.secondary)
                }
            }
            .onChange(of: self.secret, initial: true) {
                Task {
                    self.secretIdenticon = await self.secret.nonEmpty.flatMap {
                        await Spectre.shared.identicon(userName: self.userName, userSecret: $0)
                    }
                }
            }
        }
    }

    struct ToolbarView: View {
        var body: some View {
            ControlGroup {
                Button("Settings", systemImage: "gearshape.2.fill") {}
                Button("Incognito", systemImage: "eyeglasses") {}
                Button("Chat", systemImage: "bubble.left.and.bubble.right.fill") {}
            }.controlGroupStyle(.spectre(alignment: .center))
        }
    }
}

// #Preview {
struct LoginScreenPreview: PreviewProvider, View {
    static var previews: some View = Self()

    var body: some View {
        LoginScreen(model: using(.init()) {
            $0.users = [
                .init(
                    format: .default, exportDate: Date(), redacted: true, algorithm: .current, avatar: .avatar_3,
                    userName: "Robert Lee Mitchell", identicon: .from("╚☻╯⛄", color: .green)!,
                    userKeyID: .init(), lastUsed: Date(), biometricLock: true, autofill: false
                ),
                .init(
                    format: .default, exportDate: Date(), redacted: true, algorithm: .current, avatar: .avatar_10,
                    userName: "Katherine Johnson", identicon: .from("╚▒╯⛄", color: .blue)!,
                    userKeyID: .init(), lastUsed: Date(), biometricLock: false, autofill: false
                ),
                .init(
                    format: .default, exportDate: Date(), redacted: true, algorithm: .current, avatar: .avatar_8,
                    userName: "Mary Jackson", identicon: .from("═☻╝☔", color: .yellow)!,
                    userKeyID: .init(), lastUsed: Date(), biometricLock: false, autofill: false
                ),
                .init(
                    format: .default, exportDate: Date(), redacted: true, algorithm: .current, avatar: .avatar_9,
                    userName: "Dorothy Vaughan", identicon: .from("═☻╝☔", color: .yellow)!,
                    userKeyID: .init(), lastUsed: Date(), biometricLock: true, autofill: false
                ),
//                .init(
//                    format: .default, exportDate: Date(), redacted: true, algorithm: .current, avatar: .avatar_7,
//                    userName: "Valentina Tereshkova", identicon: .from("═☻╝☔", color: .yellow)!,
//                    userKeyID: .init(), lastUsed: Date(), biometricLock: false, autofill: false
//                ),
//                .init(
//                    format: .default, exportDate: Date(), redacted: true, algorithm: .current, avatar: .avatar_6,
//                    userName: "Alan Shepard", identicon: .from("═☻╝☔", color: .yellow)!,
//                    userKeyID: .init(), lastUsed: Date(), biometricLock: true, autofill: false
//                ),
//                .init(
//                    format: .default, exportDate: Date(), redacted: true, algorithm: .current, avatar: .avatar_5,
//                    userName: "Yuri Gagarin", identicon: .from("═☻╝☔", color: .yellow)!,
//                    userKeyID: .init(), lastUsed: Date(), biometricLock: false, autofill: false
//                ),
//                .init(
//                    format: .default, exportDate: Date(), redacted: true, algorithm: .current, avatar: .avatar_1,
//                    userName: "John Glenn", identicon: .from("═☻╝☔", color: .yellow)!,
//                    userKeyID: .init(), lastUsed: Date(), biometricLock: false, autofill: false
//                ),
//                .init(
//                    format: .default, exportDate: Date(), redacted: true, algorithm: .current, avatar: .avatar_13,
//                    userName: "Eileen Collins", identicon: .from("═☻╝☔", color: .yellow)!,
//                    userKeyID: .init(), lastUsed: Date(), biometricLock: false, autofill: false
//                ),
            ]
        })
        .appStyle()
    }
}
