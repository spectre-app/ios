//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import AuthenticationServices
import OrderedCollections
import SwiftUI

struct SitesScreen: View {
    let user: User

    @Environment(\.spectre)
    private var spectre: SpectreModel
    @State
    private var siteQuery = ""
    @State
    private var editingSite: Site?
    @State
    private var isPreferencesShown = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: .spectre.margin) {
                var allSites = self.user.sites.sorted()

                // Queried Site
                if let siteQuery = self.siteQuery.nonEmpty {
                    // swiftlint:disable:next redundant_discardable_let
                    let _ = allSites.removeAll { !$0.siteName.localizedCaseInsensitiveContains(siteQuery) }

                    if !allSites.contains(where: { $0.siteName == siteQuery }) {
                        SiteBox(site: Site(user: self.user, siteName: siteQuery))
                        Divider()
                    }
                }

                // AutoFill Sites
                if let autofill = self.spectre.autofill, AppFeature.autofill.isEnabled {
                    var allServiceNames = using(OrderedSet<String>()) { allServiceNames in
                        if let credentialRequest = autofill.credentialRequest {
                            allServiceNames.append(credentialRequest.credentialIdentity.serviceIdentifier.identifier)
                        }
                        if let serviceIdentifiers = autofill.serviceIdentifiers {
                            allServiceNames.append(contentsOf: serviceIdentifiers.map(\.identifier))
                        }
                    }
                    let proposedServiceName = allServiceNames.removeFirst()
                    let proposedSites = allSites.removedAll { site in
                        site.credential.flatMap { credential in
                            credential.matchesService(name: proposedServiceName)
                        } ?? false
                    }.nonEmpty?.sorted()
                    let serviceSites = allSites.removedAll { site in
                        site.credential.flatMap { credential in
                            allServiceNames.contains { serviceName in
                                credential.matchesService(name: serviceName)
                            }
                        } ?? false
                    }.sorted()

                    // Proposed Service Site
                    if let proposedSites {
                        if proposedSites.count == 1, let proposedSite = proposedSites.first {
                            SiteBox(
                                site: proposedSite, editingSite: self.$editingSite,
                                isPreferred: true, isActivated: autofill.credentialRequest != nil
                            )
                        }
                        else {
                            ForEach(proposedSites) {
                                SiteBox(site: $0, editingSite: self.$editingSite, isPreferred: true)
                            }
                        }
                    }
                    else {
                        SiteBox(site: Site(user: self.user, siteName: proposedServiceName.privateName), isPreferred: true)
                    }

                    // Service Sites
                    ForEach(serviceSites) {
                        SiteBox(site: $0, editingSite: self.$editingSite, isPreferred: true)
                    }
                    Divider()
                }

                // Remaining Sites
                ForEach(allSites.sorted()) {
                    SiteBox(site: $0, editingSite: self.$editingSite)
                }
            }
            .padding()
        }

        #if TARGET_APP
            // Navigation
        .popoverForm(item: self.$editingSite) { editingSite in
                SiteEditScreen(site: editingSite)
//                .presentationBackground(content: {
//                    Image(uiImage: editingSite.preview.data.image ?? UIImage())
//                        .resizable().aspectRatio(contentMode: .fit)
//                        .blur(radius: (editingSite.preview.data.image?.size.width) ?? .zero > 200 ? .off : .on)
//                        .mask { GradientView() }
//                        .overlay {
//                            GradientView(gradient: .stripes(
//                                tint: Color(uiColor: editingSite.preview.color),
//                                opacity1: .short, opacity2: .long
//                            ))
//                        }
//                        .mask(Rectangle().fill(Gradient(colors: [
//                            Color.white.opacity(.short),
//                            Color.white.opacity(.off),
//                        ])))
//                        .frame(maxHeight: .infinity, alignment: .top)
//                })
            }
            .popoverForm(isPresented: self.$isPreferencesShown) {
                UserEditScreen(user: self.user)
//                .presentationBackground(content: {
//                    Image(uiImage: editingSite.preview.data.image ?? UIImage())
//                        .resizable().aspectRatio(contentMode: .fit)
//                        .blur(radius: (editingSite.preview.data.image?.size.width) ?? .zero > 200 ? .off : .on)
//                        .mask { GradientView() }
//                        .overlay {
//                            GradientView(gradient: .stripes(
//                                tint: Color(uiColor: editingSite.preview.color),
//                                opacity1: .short, opacity2: .long
//                            ))
//                        }
//                        .mask(Rectangle().fill(Gradient(colors: [
//                            Color.white.opacity(.short),
//                            Color.white.opacity(.off),
//                        ])))
//                        .frame(maxHeight: .infinity, alignment: .top)
//                })
            }
        #endif

            // Behaviour
            .animation(.default, value: self.siteQuery)
            .searchable(text: self.$siteQuery, prompt: "eg. apple.com")
            .navigationTitle(self.user.userName)
            .onChange(of: self.user.sites) {
                if let editingSite, !self.user.sites.contains(where: { $0.siteName == editingSite.siteName }) {
                    self.editingSite = nil
                }
            }
            .toolbar {
                Group {
                    if self.spectre.autofill == nil {
                        Button("Preferences") {
                            self.isPreferencesShown = true
                        }
                    }

                    Button("Sign Out") {
                        self.user.logout()
                    }
                }
                .labelStyle(.spectre)
            }
    }

    struct SiteBox: View {
        let site: Site
        var editingSite: Binding<Site?>?
        var isPreferred = false
        var isActivated = false

        @State
        private var mode: SpectreKeyPurpose = .authentication
        @State
        private var isEditing = false
        @Environment(\.spectre)
        private var spectre: SpectreModel
        @Environment(\.messages)
        private var messages: MessagesModel

        var body: some View {
            Group {
                if let autofill = self.spectre.autofill {
                    Button {
                        Task { await self.perform(autofill: autofill) }
                    } label: {
                        self.titleView
                        self.resultView
                        self.loginView
                    }
                    .disabled(AppFeature.autofill.isEnabled)
                    .buttonStyle(.spectreBox {
                        Color.spectre.selection
                            .blur(radius: .spectre.margin)
                            .background(ContainerRelativeShape().stroke(Color.spectre.tint))
                            .opacity(self.isPreferred ? .on : .off)
                    })
                    .onChange(of: self.isActivated, initial: true) { _, isActivated in
                        if isActivated {
                            Task { await self.perform(autofill: autofill) }
                        }
                    }
                }
                else {
                    GroupBox {
                        self.resultView
                        self.modeView
                    } label: {
                        self.titleView
                        Spacer()
                        self.editView
                    }
                    .groupBoxStyle(.spectre {
                        Color.spectre.selection
                            .blur(radius: .spectre.margin)
                            .background(ContainerRelativeShape().stroke(Color.spectre.tint))
                            .opacity(self.isPreferred ? .on : .off)
                    })
                }
            }
            .shadow(color: .spectre.shadow, radius: .on)
        }

        @ViewBuilder
        private var titleView: some View {
            Text(self.site.siteName) + Text(self.editingSite == nil ? " (new)" : "")
        }

        @ViewBuilder
        private var resultView: some View {
            if let result = self.site.result(keyPurpose: self.mode) {
                AsyncView(onChange: result) { try await $0.task.value } finished: { resultText in
                    HStack(spacing: .zero) {
                        Text(resultText ?? "...")
                            .font(.spectre.password)
                            .lineLimit(1)
                            .minimumScaleFactor(.short)

                        if self.spectre.autofill == nil {
                            Spacer()

                            if self.editingSite == nil {
                                Button("Add", systemImage: "plus.rectangle.on.rectangle") {
                                    self.site.user?.sites.append(self.site)
                                }
                            }
                            else {
                                Button("Copy", systemImage: "doc.on.doc") {
                                    result.copy()
                                }
                            }
                        }
                    }
                } failure: { _ in }
            }
        }

        @ViewBuilder
        private var modeView: some View {
            // TODO: Allow switching to a different mode
            // TODO: Show strength indicator?
            HStack {
                Color.spectre.mute.frame(height: 1)
                ForEach(type(of: self.mode).allCases) { mode in
                    Group {
                        switch mode {
                            case .authentication: Image(systemName: "key.horizontal")
                            case .identification: Image(systemName: "person.crop.rectangle")
                            case .recovery: Image(systemName: "person.crop.circle.badge.questionmark")
                            @unknown default: Image(systemName: "questionmark")
                        }
                    }
                    .foregroundColor(self.mode == mode ? nil : .spectre.mute)
                    .onTapGesture { self.mode = mode }
                }
                Color.spectre.mute.frame(height: 1)
            }
            .font(.spectre.caption1)
        }

        @ViewBuilder
        private var loginView: some View {
            if AppFeature.logins.isEnabled, let result = self.site.result(keyPurpose: .identification) {
                AsyncView(onChange: result) { try await $0.task.value } finished: { resultText in
                    Text(resultText ?? "...")
                        .font(.spectre.callout)
                        .lineLimit(1)
                        .minimumScaleFactor(.short)
                } failure: { _ in }
            }
        }

        @ViewBuilder
        private var editView: some View {
            if let editingSite = self.editingSite {
                Button("Edit", systemImage: "pencil") {
                    editingSite.wrappedValue = self.site
                }
                .onChange(of: self.isActivated, initial: true) { _, isActivated in
                    if isActivated {
                        editingSite.wrappedValue = self.site
                    }
                }
            }
        }

        private func perform(autofill: SpectreModel.AutoFill) async {
            do {
                if AppFeature.autofill.isEnabled,
                   let login = AppFeature.logins.isEnabled ? try await self.site.result(keyPurpose: .identification)?.task.value : "",
                   let password = try await self.site.result(keyPurpose: .authentication)?.task.value {
                    inf("Autofilling manually: \(login), for site: \(self.site.siteName)")
                    Feedback.shared.play(.activate)

                    if await autofill.complete(with: .init(user: login, password: password)) {
                        self.site.domains.formUnion(autofill.serviceIdentifiers?.flatMap(\.identifier.variantNames) ?? [])
                        self.site.use()
                    }
                }
            }
            catch {
                err("Couldn't compute site result", data: error)
            }
        }
    }
}

#if DEBUG
#Preview {
    SitesScreen(user: User(avatar: .avatar_3, userName: "Robert Lee Mitchell") { user in
        user.sites.append(contentsOf: [
            Site(user: user, siteName: "apple.com"),
            Site(user: user, siteName: "modem"),
            Site(user: user, siteName: "gog.com"),
            using(Site(user: user, siteName: "twitter.com")) {
                $0.questions += [
                    Question(site: $0, keyword: "mother"),
                    Question(site: $0, keyword: "film"),
                    Question(site: $0, keyword: "teacher"),
                ]
            },
            Site(user: user, siteName: "wesnoth.org"),
        ])

        Task {
            try? await user.login(using: SecretKeyFactory(
                userName: user.userName, userSecret: "banana duckling"
            ))
        }
    })
    .spectreStyle()
    .environment(\.spectre, using(.shared) { $0.autofill = .init(
        serviceIdentifiers: [.init(identifier: "spectre.app", type: .domain)]
    ) })
    .task { AppConfig.shared.testingPremium = true }
}
#endif
