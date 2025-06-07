//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import SwiftUI
import WrappingHStack

struct SettingsScreen: View {
    @EnvironmentObject
    private var config: AppConfig
    @Environment(\.requestReview)
    private var requestReview
    @State
    private var submittingRating = false
    @State
    private var comment = ""
    @State
    private var email = ""
    @StateObject
    private var tracker = Tracker.shared
    @State
    private var isPremiumPresented = false
    @State
    private var isLogbookPresented = false
    @State
    private var isReviewQuestionPresented = false
    @State
    private var isReviewPresented = false

    var body: some View {
        Form {
            self.headerSection
            self.preferencesSection
            self.styleSection
            self.linksSection
        }
        .labeledContentStyle(.spectreCaptioned)
        .multilineTextAlignment(.center)

        // Behaviour
        .popoverTitle(productName)
    }

    @ViewBuilder
    private var headerSection: some View {
        Section {
            Image(self.config.appIcon.glyphName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .cornerRadius(.spectre.spacer)
                .frame(maxWidth: .infinity, idealHeight: .spectre.shape)

            LabeledContent("Build \(productBuild)\(self.config.isDebug ? "D" : "") (\(self.config.environment.description))") {
                Text("\(productVersion)")
                    .font(.spectre.title1)
                    .frame(maxWidth: .infinity)
            }

            Divider()

            // TODO: Countly feedback plugin not available in Flex plan.
//            LabeledContent("How are we doing?") {
//                VStack {
//                    HStack {
//                        ForEach(1 ... 5, id: \.self) { rating in
//                            Button {
//                                self.submittingRating = true
//                                self.config.rating = rating
//                            } label: {
//                                Image(systemName: rating <= self.config.rating ? "star.fill" : "star")
//                            }
//                        }
//                    }
//
//                    if self.submittingRating {
//                        TextArea(prompt: self.ratingPrompt, text: self.$comment)
//                            .multilineTextAlignment(.center)
//
//                        LabeledContent("Can we get back to you?") {
//                            TextField(prompt: "E-mail address", text: self.$email)
//                                .submitLabel(.done)
//                                .textContentType(.emailAddress)
//                                .textInputAutocapitalization(.never)
//                                .autocorrectionDisabled()
//                                .keyboardType(.emailAddress)
//                        }
//                        .labeledContentStyle(.spectreVertical)
//                        .textContentType(.emailAddress)
//                        .keyboardType(.emailAddress)
//                        .onSubmit(self.submitRating)
//                        .submitLabel(.send)
//
//                        Button("Send your rating", action: self.submitRating)
//                    }
//                }
//            }
//            .alert("Publish Review?", isPresented: self.$isReviewQuestionPresented) {
//                Button( "Not now", role: .cancel ) {}
//                Button( "I will!" ) {
//                    self.isReviewPresented = true
//                    self.config.reviewed = Date()
//                }
//            } message: {
//                Text(
//                    """
//                    Sharing your thoughts on the App Store helps us immeasurably.
//                    Would you like to write a short public review?
//                    """
//                )
//            }
//            .popoverForm(isPresented: self.$isReviewPresented) {
//                if let url = URL( string: "https://apps.apple.com/us/app/password-spectre/id1526402806?action=write-review" ) {
//                    WebView(url: url)
//                }
//            }
//            .disabled(self.config.offline)
        }
    }

    @ViewBuilder
    private var preferencesSection: some View {
        Section("Preferences") {
            LabeledContent("Be notified of important impacts on your security.") {
                Toggle("Notifications", systemImage: "bell", isOn: .init { self.config.notifications } set: { enabled in
                    Task {
                        if enabled {
                            await self.tracker.enableNotifications()
                        }
                        else {
                            await self.tracker.disableNotifications()
                        }
                    }
                })
            }

            LabeledContent("Anonymously send app issues to development for resolution.") {
                Toggle("Diagnostics", systemImage: "cross.case", isOn: self.$config.diagnostics)
            }
            .disabled(self.config.offline)

            LabeledContent("Disable any features that may use the Internet.") {
                Toggle("Offline Mode", systemImage: "network.slash", isOn: self.$config.offline)
            }

            StoreContent(feature: .handoff) {
                LabeledContent("Allow pasting to other devices via Apple Handoff.") {
                    Toggle("Handoff", systemImage: "macbook.and.iphone", isOn: self.$config.allowHandoff)
                }
                .disabled(self.config.offline)
            }
        }
        .multilineTextAlignment(.leading)
    }

    @ViewBuilder
    private var styleSection: some View {
        Section("Style") {
            StoreContent(feature: .style) {
                LabeledContent(self.config.theme.mood) {
                    Picker("Theme", selection: self.$config.theme) {
                        ForEach(type(of: self.config.theme).allCases) {
                            RoundedRectangle(cornerRadius: .spectre.spacer)
                                .fill($0.flat ?? .init(red: .zero, green: .zero, blue: .zero, opacity: .zero))
                        }
                    }
                    .overlay(Image(systemName: "paintbrush"))
                    .pickerStyle(.wheel)
                }
            }

            StoreContent(feature: .icons) {
                LabeledContent("Pick your favourite home screen icon for \(productName).") {
                    Carousel(values: type(of: self.config.appIcon).allCases, selection: .init {
                        self.config.appIcon
                    } set: {
                        $0.activate()
                    }) {
                        Image($0.logoName)
                            .resizable()
                            .frame(width: .spectre.shape / 2, height: .spectre.shape / 2)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var linksSection: some View {
        Section("Links") {
            WrappingHStack {
                Button("Manage Premium") {
                    self.isPremiumPresented = true
                }
                .popoverForm(isPresented: self.$isPremiumPresented) {
                    PremiumScreen()
                }

                Button("Logbook") {
                    self.isLogbookPresented = true
                }
                .popoverForm(isPresented: self.$isLogbookPresented) {
                    LogScreen()
                }
            }
            .frame(maxWidth: .infinity)

            Divider()

            WrappingHStack {
                Link("Home", destination: URL(string: "https://spectre.app")!)
                Link("Questions", destination: URL(string: "https://chat.spectre.app")!)
                Link("White Paper", destination: URL(string: "https://spectre.app/spectre-algorithm.pdf")!)
                Link("User Agreement", destination: URL(string: "https://spectre.app/policy/eula/")!)
                Link("Privacy Policy", destination: URL(string: "https://spectre.app/policy/privacy/")!)
                Link("Source Code Portal", destination: URL(string: "https://source.spectre.app")!)
            }

            Divider()

            Text("\(Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? "") — Spectre®")
                .font(.spectre.caption1)
                .frame(maxWidth: .infinity)
        }
    }

    private var ratingPrompt: String {
        if self.config.rating <= 2 {
            "Sorry about that! What's going wrong?"
        }
        else if self.config.rating <= 3 {
            "What could we do better for you?"
        }
        else {
            "Thanks! Leave us a comment?"
        }
    }

    private func submitRating() {
        Tracker.shared.feedback(self.config.rating, comment: self.comment.nonEmpty, contact: self.email.nonEmpty)

        if self.config.reviewed == .distantPast, self.config.rating == 5 {
            if !self.comment.isEmpty {
                self.isReviewQuestionPresented = true
            }
            else {
                self.config.reviewed = Date()
                self.requestReview()
            }
        }
        self.submittingRating = false
    }
}

#if DEBUG
#Preview {
    Path().popoverForm(isPresented: .constant(true)) {
        SettingsScreen()
    }
    .spectreStyle()
}
#endif
