//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import SwiftUI

struct SiteDeltaScreen: View {
    let old: Site
    let new: Site

    var body: some View {
        Form {
            Section(self.new.siteName) {
                PairView(
                    label: "Name",
                    old: self.old.siteName,
                    new: self.new.siteName
                )
                PairView(
                    label: "Algorithm",
                    old: self.old.algorithm.localizedDescription,
                    new: self.new.algorithm.localizedDescription
                )
                PairView(
                    label: "Counter",
                    old: self.old.counter.description,
                    new: self.new.counter.description
                )
                if AppFeature.logins.isEnabled {
                    PairResultView(
                        label: "Login",
                        oldLabel: self.old.loginType.localizedDescription,
                        old: self.old.result(keyPurpose: .identification),
                        newLabel: self.new.loginType.localizedDescription,
                        new: self.new.result(keyPurpose: .identification)
                    )
                }
                PairResultView(
                    label: "Password",
                    oldLabel: self.old.resultType.localizedDescription,
                    old: self.old.result(keyPurpose: .authentication),
                    newLabel: self.new.resultType.localizedDescription,
                    new: self.new.result(keyPurpose: .authentication)
                )
                if AppFeature.answers.isEnabled {
                    PairResultView(
                        label: "Recovery Answer",
                        old: self.old.result(keyPurpose: .recovery),
                        new: self.new.result(keyPurpose: .recovery)
                    )
                    let oldQuestions = self.old.questions.sorted(), newQuestions = self.new.questions.sorted()
                    ForEach(0 ..< max(oldQuestions.count, newQuestions.count), id: \.self) { q in
                        PairResultView(
                            label: "Specific Answer #\(q + 1)",
                            oldLabel: q >= self.old.questions.count ? nil : self.old.questions[q].keyword,
                            old: q >= self.old.questions.count ? nil : self.old.questions[q].result(),
                            newLabel: q >= self.new.questions.count ? nil : self.new.questions[q].keyword,
                            new: q >= self.new.questions.count ? nil : self.new.questions[q].result()
                        )
                    }
                }
            }
        }
        .labeledContentStyle(.spectreVertical)

        // Behaviour
        .navigationTitle("Site changes")
        .modify {
            $0
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
    }

    struct PairView: View {
        let label: String
        let old: String?
        let new: String?

        var body: some View {
            if let old, let new, old != new {
                VStack {
                    Text(self.label)
                        .font(.headline)

                    HStack {
                        LabeledContent("Before") {
                            Text(old)
                        }
                        .multilineTextAlignment(.leading)
                        LabeledContent("Now") {
                            Text(new)
                        }
                        .multilineTextAlignment(.trailing)
                    }
                    .labeledContentStyle(.spectreCaptioned)
                }
            }
        }
    }

    struct PairResultView: View {
        let label: String
        var oldLabel: String?
        let old: SpectreOperation?
        var newLabel: String?
        let new: SpectreOperation?

        var body: some View {
            AsyncView(onChange: [self.old, self.new]) { try await [$0[0]?.task.value, $0[1]?.task.value] } finished: { results in
                if let results, results[0] != results[1] {
                    VStack {
                        Text(self.label)
                            .font(.headline)

                        HStack(spacing: .zero) {
                            LabeledContent("Before" + (self.oldLabel.flatMap { " (\($0))" } ?? "")) {
                                Button(results[0] ?? "N/A", systemImage: "doc.on.doc") {
                                    self.old?.copy()
                                }
                                .disabled(results[0] == nil)
                            }
                            .multilineTextAlignment(.leading)

                            LabeledContent("Now" + (self.newLabel.flatMap { " (\($0))" } ?? "")) {
                                Button(results[1] ?? "N/A", systemImage: "doc.on.doc") {
                                    self.new?.copy()
                                }
                                .disabled(results[1] == nil)
                            }
                            .multilineTextAlignment(.trailing)
                        }
                        .labeledContentStyle(.spectreCaptioned)
                        .multilineTextAlignment(.center)
                    }
                }
            } failure: { _ in /* TODO: */ }
        }
    }
}

#if DEBUG
#Preview {
    let user = User(userName: "Robert Lee Mitchell", file: nil)
    let oldSite = Site(user: user, siteName: "spectre.app")
    oldSite.questions.append(Question(site: oldSite, keyword: "foo"))
    oldSite.questions.append(Question(site: oldSite, keyword: "bar"))
    oldSite.questions.append(Question(site: oldSite, keyword: "quux"))
    let newSite = Site(
        user: user, siteName: "spectre.pw", algorithm: .V0, counter: .TOTP,
        resultType: .templateMaximum, loginType: .templatePhrase
    )
    newSite.questions.append(Question(site: newSite, keyword: "foo"))
    newSite.questions.append(Question(site: oldSite, keyword: "baz"))

    return SiteDeltaScreen(old: oldSite, new: newSite)
        .task { _ = try? await user.login(using: SecretKeyFactory(userName: user.userName, userSecret: "banana colored duckling")) }
        .spectreStyle()
}
#endif
