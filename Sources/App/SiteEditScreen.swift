//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import SwiftUI

struct SiteEditScreen: View {
    @Bindable
    var site: Site

    @State
    private var addingAnswerKeyword = ""
    @State
    private var isAddingAnswer = false
    @FocusState
    private var isAddingAnswerFocused
    @Environment(\.messages)
    private var messages: MessagesModel

    var body: some View {
        // TODO: UI for updating existing password to new one
        Form {
            self.editMyAccount
            self.editCounter
            self.editType
            self.editSecurityQuestions
            self.editDetails
        }

        // Behaviour
        .popoverTitle("Edit site")
    }

    var editMyAccount: some View {
        Section(self.site.siteName) {
            if let result = self.site.result(keyPurpose: .identification) {
                StoreContent(feature: .logins) {
                    LabeledContent("Login") {
                        AsyncView(onChange: result) { try await $0.task.value } finished: {
                            Button($0 ?? "...", systemImage: "doc.on.doc") {
                                result.copy()
                            }
                        } failure: { _ in /* TODO: */ }
                    }
                }
            }

            if let result = self.site.result(keyPurpose: .authentication) {
                LabeledContent("Password") {
                    AsyncView(onChange: result) { try await $0.task.value } finished: {
                        Button($0 ?? "...", systemImage: "doc.on.doc") {
                            result.copy()
                        }
                    } failure: { _ in /* TODO: */ }
                }
            }

            if let result = self.site.result(keyPurpose: .recovery) {
                StoreContent(feature: .answers) {
                    LabeledContent("Recovery Answer") {
                        AsyncView(onChange: result) { try await $0.task.value } finished: {
                            Button($0 ?? "...", systemImage: "doc.on.doc") {
                                result.copy()
                            }
                        } failure: { _ in /* TODO: */ }
                    }
                    .labeledContentStyle(.spectreVertical)
                }
            }

            ControlGroup {
                if let user = self.site.user {
                    Button("Delete") {
                        self.messages.prompt(message: "Remove this site from \(user.userName)?", options: [
                            (true, "Delete \(self.site.siteName)"),
                            (false, "Cancel"),
                        ]) { shouldDelete in
                            guard shouldDelete else { return }

                            user.sites.removeAll { $0.siteName == self.site.siteName }
                        }
                    }
                }
            }
        }.groupBoxStyle(.spectre(systemImage: "signature"))
    }

    var editCounter: some View {
        Section("Counter") {
            Stepper("Using Password #\(self.site.counter)" as String, value: self.$site.counter)

            Text("The counter allows you to generate a new login if the current information can no longer be trusted.")
                .font(.spectre.caption1)
        }.groupBoxStyle(.spectre(systemImage: "number"))
    }

    var editType: some View {
        Section("Login Types") {
            StoreContent(feature: .logins) {
                Picker(selection: self.$site.loginType) {
                    ForEach([SpectreResultType].joined(
                        [SpectreResultType.none],
                        SpectreResultType.recommendedTypes[.identification],
                        [.statePersonal],
                        SpectreResultType.allCases.filter { !$0.has(feature: .alternate) }
                    ).unique()) { type in
                        if type == .none {
                            Text("User Login (\(self.site.user?.loginType.localizedDescription ?? type.localizedDescription))")
                        }
                        else {
                            Text(type.localizedDescription)
                        }
                    }
                } label: {
                    Text("Login")
                }
            }

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

            StoreContent(feature: .strength) {
                LabeledContent("Time to crack") {
                    AsyncView(onChange: self.site.user?.attacker ?? .default) {
                        if !AppFeature.strength.isEnabled {
                            nil as TimeToCrack?
                        }
                        else if let result = $0.timeToCrack(type: self.site.resultType) {
                            result
                        }
                        else {
                            await $0.timeToCrack(string: try? self.site.result()?.task.value)
                        }
                    } finished: { timeToCrack in
                        Text((timeToCrack ?? nil)?.description ?? "N/A")
                    }
                }
                .labeledContentStyle(.spectreVertical)
            }

            Text("Customize the strength and appearance of the site's login information.")
                .font(.spectre.caption1)
        }.groupBoxStyle(.spectre(systemImage: "checkerboard.shield"))
    }

    var editSecurityQuestions: some View {
        Section("Security Questions") {
            StoreContent(feature: .answers) {
                ForEach(self.site.questions.sorted()) { question in
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

                Button {
                    self.addingAnswerKeyword = ""
                    self.isAddingAnswer = true
                    self.isAddingAnswerFocused = true
                } label: {
                    Label {
                        if self.isAddingAnswer {
                            TextField(prompt: "eg. teacher", text: self.$addingAnswerKeyword)
                                .submitLabel(.done)
                                .textContentType(.jobTitle)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.alphabet)
                                .fixedSize(horizontal: true, vertical: false)
                                .focused(self.$isAddingAnswerFocused)
                                .onSubmit {
                                    if let keyword = self.addingAnswerKeyword.nonEmpty {
                                        self.site.questions.append(.init(site: self.site, keyword: keyword))
                                    }
                                    self.isAddingAnswer = false
                                }
                        }
                        else {
                            Text("Add Custom Question")
                        }
                    } icon: {
                        Image(systemName: "plus.bubble")
                    }
                }
            }

            Text("To avoid disclosing vulnerable personal information, use these to answer the site's security questions.")
                .font(.spectre.caption1)
        }.groupBoxStyle(.spectre(systemImage: "bubble.left.and.exclamationmark.bubble.right"))
    }

    var editDetails: some View {
        Section("Details") {
            LabeledContent("Landing page") {
                TextField(prompt: "eg. https://spectre.app", text: Binding(
                    get: { self.site.url ?? "" },
                    set: { self.site.url = $0.nonEmpty }
                ))
                .submitLabel(.done)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            }
            .labeledContentStyle(.spectreVertical)

            LabeledContent("Associated domains") {
                TextArea(prompt: "eg. spectre.app", text: Binding(
                    get: { self.site.domains.joined(separator: "\n") },
                    set: { self.site.domains = .init($0.split(separator: /[\n,]/).map(String.init)) }
                ))
                .submitLabel(.done)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            }
            .labeledContentStyle(.spectreVertical)

            Picker(selection: self.$site.algorithm) {
                ForEach(SpectreAlgorithm.allCases) { type in
                    Text(type.localizedDescription)
                }
            } label: {
                Text("Algorithm")
            }
            .foregroundColor(self.site.algorithm != .current ? .red : nil)

            LabeledContent("Recorded uses") {
                Text("^[\(self.site.uses) times](inflect: true)")
                    .font(.spectre.callout)
            }

            LabeledContent("Last use") {
                Text(self.site.lastUsed.formatted())
                    .font(.spectre.callout)
            }
        }.groupBoxStyle(.spectre(systemImage: "note.text"))
    }
}

#if DEBUG
#Preview {
    Path().popoverForm(isPresented: .constant(true)) {
        SiteEditScreen(
            site: Site(user: nil, siteName: "spectre.app")
        )
    }
    .spectreStyle()
}
#endif
