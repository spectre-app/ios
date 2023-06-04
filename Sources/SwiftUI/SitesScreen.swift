//
//  SitesScreen.swift
//  Spectre
//
//  Created by Maarten Billemont on 2023-09-01.
//  Copyright © 2023 Lyndir. All rights reserved.
//

import SwiftUI

struct SitesScreen: View {
    @State
    var activeUser: User
    @State
    var siteQuery: String = ""

    var body: some View {
        List {
            Group {
                if !self.siteQuery.isEmpty, !self.activeUser.sites.contains(where: {
                    $0.siteName == self.siteQuery
                }) {
                    SiteBox(site: Site(user: self.activeUser, siteName: self.siteQuery))
                }

                ForEach(self.activeUser.sites.sorted().filter {
                    self.siteQuery.isEmpty
                    || $0.siteName.localizedCaseInsensitiveContains(self.siteQuery)
                }) {
                    SiteBox(site: $0)
                }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .background()

        // Behaviour
        .animation(.default, value: self.siteQuery)
        .searchable(text: self.$siteQuery, prompt: "eg. apple.com")
        .navigationTitle(self.activeUser.userName)
        .toolbar {
            ToolbarItem {
                Button("Sign Out", systemImage: "escape") {
                    self.activeUser.logout()
                }
            }
        }
    }

    struct SiteBox: View {
        @State
        var site: Site

        @State
        private var mode: SpectreKeyPurpose = .authentication
        @State
        private var isEditing = false
        @State
        private var timeToCrack: TimeToCrack?

        var body: some View {
            GroupBox {
                if let result = self.site.result(keyPurpose: self.mode) {
                    AsyncView(onChange: result) { try await $0.task.value } finished: { resultText in
                        HStack(spacing: .zero) {
                            Text(resultText ?? "...")
                                .font(.spectre.password)
                                .lineLimit(1)
                                .minimumScaleFactor(.short)

                            Spacer()

                            Button("Copy", systemImage: "doc.on.doc") {
                                result.copy()
                            }
                        }
                    } failure: { _ in }
                }

                HStack {
                    Picker("Show Type", selection: self.$mode) {
                        ForEach(type(of: self.mode).allCases) {
                            switch $0 {
                                case .authentication: Image(systemName: "key.horizontal")
                                case .identification: Image(systemName: "person.crop.rectangle")
                                case .recovery: Image(systemName: "person.crop.circle.badge.questionmark")
                                @unknown default: Image(systemName: "questionmark")
                            }
                        }
                    }
                    .pickerStyle(.palette)
                    .paletteSelectionEffect(.custom)
                    Spacer()
                }
            } label: {
                Text(self.site.siteName)

                Button("Edit", systemImage: "pencil") {
                    self.isEditing = true
                }
            }
            .groupBoxStyle(.spectre {
                Image(uiImage: self.site.preview.data.image ?? UIImage())
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 20)
                    .background(Color(uiColor: self.site.preview.color))
                    .opacity(.long)
            })
            .sheet(isPresented: self.$isEditing) {
                self.editBody
                    .background()
                    .appStyle()
            }
        }

        var editBody: some View {
            List {
                Group {
                    self.editMyAccount

                    self.editCounter

                    self.editType

                    self.editSecurityQuestions

                    self.editDetails
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            // Behaviour
            .navigationTitle(self.site.siteName)
            .task {
                let attacker = self.site.user?.attacker ?? .default
                self.timeToCrack = InAppFeature.premium.isEnabled
                ? await attacker.timeToCrack(type: self.site.resultType) ???
                (await attacker.timeToCrack(string: try? self.site.result()?.task.value))
                : nil
            }
        }

        var editMyAccount: some View {
            GroupBox("My account") {
                if let result = self.site.result(keyPurpose: .identification) {
                    AsyncView(onChange: result) { try await $0.task.value } finished: { resultText in
                        LabeledContent("Login") {
                            Button(resultText ?? "...", systemImage: "doc.on.doc") {
                                result.copy()
                            }
                        }
                    } failure: { _ in }
                }

                if let result = self.site.result(keyPurpose: .authentication) {
                    AsyncView(onChange: result) { try await $0.task.value } finished: { resultText in
                        LabeledContent("Password") {
                            Button(resultText ?? "...", systemImage: "doc.on.doc") {
                                result.copy()
                            }
                        }
                    } failure: { _ in }
                }
            }.groupBoxStyle(.spectre(systemImage: "signature"))
        }

        var editCounter: some View {
            GroupBox("Counter") {
                Stepper("Password #\(self.site.counter)" as String, value: self.$site.counter)

                Text("Increment the counter if the site's password needs to be changed.")
                    .font(.spectre.caption1)
            }.groupBoxStyle(.spectre(systemImage: "number"))
        }

        var editType: some View {
            GroupBox("Type") {
                Picker(selection: self.$site.loginType) {
                    ForEach([SpectreResultType].joined(
                        [SpectreResultType.none],
                        SpectreResultType.recommendedTypes[.identification],
                        [.statePersonal],
                        SpectreResultType.allCases.filter { !$0.has(feature: .alternate) }
                    ).unique()) { type in
                        if type == .none {
                            Text("User Login (\(self.site.user?.loginType.localizedDescription ?? ""))")
                        } else {
                            Text(type.localizedDescription)
                        }
                    }
                } label: {
                    Text("Login 🅿︎")
                }
                .disabled(!InAppFeature.premium.isEnabled)

                Picker(selection: self.$site.resultType) {
                    ForEach([SpectreResultType].joined(
                        SpectreResultType.recommendedTypes[.authentication],
                        [SpectreResultType.statePersonal],
                        SpectreResultType.allCases.filter { !$0.has(feature: .alternate) }
                    ).unique()) { type in
                        Text(type.localizedDescription)
                    }
                } label: {
                    Text("Password")
                }

                LabeledContent("Time to crack 🅿︎") {
                    Text(self.timeToCrack?.description ?? "N/A")
                }
                .labeledContentStyle(.spectreVertical)

                Text("Customize the strength and appearance of the site's login information.")
                    .font(.spectre.caption1)
            }.groupBoxStyle(.spectre(systemImage: "checkerboard.shield"))
        }

        var editSecurityQuestions: some View {
            GroupBox("Security Questions") {
                if let result = self.site.result(keyPurpose: .recovery) {
                    AsyncView(onChange: result) { try await $0.task.value } finished: { resultText in
                        LabeledContent("Recovery Answer") {
                            Button(resultText ?? "...", systemImage: "doc.on.doc") {
                                result.copy()
                            }
                        }
                        .labeledContentStyle(.spectreVertical)
                    } failure: { _ in }
                }

                Divider()

                ForEach(self.site.questions) { question in
                    if let result = question.result() {
                        LabeledContent(question.keyword) {
                            HStack(spacing: .zero) {
                                AsyncView(onChange: result) { try await $0.task.value } finished: {
                                    Button($0 ?? "...", systemImage: "doc.on.doc") {
                                        result.copy()
                                    }
                                } failure: {
                                    Text($0.localizedDescription)
                                }

                                Spacer()

                                Button("Remove", systemImage: "trash.circle") {
                                    self.site.questions.removeAll { $0.id == question.id }
                                }
                            }
                        }.labeledContentStyle(.spectreVertical)
                    }
                }

                LabeledContent("Custom Answer") {
                    Button("Add", systemImage: "plus.bubble") {
                        //TODO
                    }
                }

                Text("Use these answers for the site security questions to avoid using vulnerable personal information.")
                    .font(.spectre.caption1)
            }.groupBoxStyle(.spectre(systemImage: "bubble.left.and.exclamationmark.bubble.right"))
        }

        var editDetails: some View {
            GroupBox("Details") {
                TextField("URL", text: Binding(
                    get: { self.site.url ?? "" },
                    set: { self.site.url = $0.nonEmpty }
                ))

                Picker(selection: self.$site.algorithm) {
                    ForEach(SpectreAlgorithm.allCases) { type in
                        Text(type.localizedDescription)
                    }
                } label: {
                    Text("Algorithm")
                }

                LabeledContent("Recorded uses") {
                    Text("^[\(self.site.uses) times](inflect: true)")
                        .font(.spectre.callout)
                }

                LabeledContent("Last use") {
                    Text(self.site.lastUsed.formatted())
                        .font(.spectre.callout)
                }

                Text("Additional information about the site.")
                    .font(.spectre.caption1)
            }.groupBoxStyle(.spectre(systemImage: "note.text"))
        }
    }
}

#Preview {
    SitesScreen(activeUser: User(avatar: .avatar_3, userName: "Robert Lee Mitchell") { user in
        user.sites.append(contentsOf: [
            Site(user: user, siteName: "apple.com"),
            using(Site(user: user, siteName: "twitter.com")) {
                $0.questions += [
                    Question(site: $0, keyword: "mother"),
                    Question(site: $0, keyword: "film"),
                    Question(site: $0, keyword: "teacher"),
                ]
            },
        ])
        Task {
            try? await user.login(using: SecretKeyFactory(
                userName: user.userName, userSecret: "banana duckling"
            ))
        }
    })
    .appStyle()
    .task {
        InAppFeature.premium.enable(true)
    }
}
