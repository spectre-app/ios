//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import StoreKit
import SwiftUI

struct StoreContent<Content: View>: View {
    var feature: AppFeature
    var alignment: Alignment = .leading
    @ViewBuilder
    let content: () -> Content

    @EnvironmentObject
    private var config: AppConfig
    @State
    private var isPresented = false

    var body: some View {
        ZStack(alignment: self.alignment) {
            GradientView(width: .spectre.margin)
                .cornerRadius(.spectre.margin)
                .opacity(.short)
                .padding(.horizontal, -.spectre.margin)
                .mask { Color.black.blur(radius: .spectre.padding) }
                .opacity(!self.feature.isPurchaseNeeded ? .off : .on)

            VStack {
                self.content()
            }
            .disabled(!self.feature.isEnabled)

            Image(systemName: "star.circle.fill")
                .font(.spectre.headline)
                .padding(.spectre.padding / 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .onTapGesture {
            if self.feature.isPurchaseNeeded {
                self.isPresented = true
            }
        }
        .popoverForm(isPresented: self.$isPresented) {
            PremiumScreen()
        }
    }
}

struct PremiumScreen: View {
    @Environment(\.spectre)
    private var spectre: SpectreModel
    @Environment(\.messages)
    private var messages: MessagesModel
    @EnvironmentObject
    private var config: AppConfig
    @State
    private var isRedeemingCode = false
    @State
    private var premium: EntitlementTaskState<[Product.SubscriptionInfo.Status]> = .loading
    @State
    private var products: Product.CollectionTaskState = .loading

    var body: some View {
        ScrollView {
            VStack(spacing: .spectre.margin) {
                LabeledContent("Enable enhanced comfort and security features.") {
                    Image(systemName: "star.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, idealHeight: .spectre.shape)
                }

                #if !PUBLIC
                Toggle("Test Premium", systemImage: "testtube.2", isOn: self.$config.testingPremium)

                if self.config.testingPremium {
                    LabeledContent("Thank you for making Spectre possible!") {
                        Image(systemName: "checkmark")
                            .font(.spectre.largeTitle)
                    }
                }

                Divider()
                #endif

                switch self.premium {
                    case .loading: ProgressView("Checking subscription").frame(maxWidth: .infinity)

                    case let .failure(error): Text(error.localizedDescription)

                    case let .success(premium) where premium.contains { [.subscribed, .inGracePeriod].contains($0.state) }:
                        LabeledContent("Thank you for making Spectre possible!") {
                            Image(systemName: "checkmark")
                                .font(.spectre.largeTitle)
                        }

                    case .success:
                        switch self.products {
                            case .loading: ProgressView("Loading products").frame(maxWidth: .infinity)
                            case let .failure(error): Text(error.localizedDescription)
                            case let .success(available, _):
                                SubscriptionStoreView(subscriptions: available) {
                                    PremiumFeatures()
                                }
                                .subscriptionStoreButtonLabel(.multiline)
                                .subscriptionStoreControlStyle(.prominentPicker)
                                .subscriptionStoreControlBackground(.clear)
                                .subscriptionStorePickerItemBackground(.clear)
                                .storeButton(.hidden, for: .cancellation, .signIn)
                                .storeButton(.visible, for: .policies)

                                if AppStore.canMakePayments {
                                    Divider()

                                    LabeledContent(
                                        "If your existing subscription wasn't automatically activated, you may need to restore it."
                                    ) {
                                        Button("Restore Subscription") {
                                            Task {
                                                // swiftlint:disable:next statement_position - FIXME: https://github.com/realm/SwiftLint/issues/4632
                                                do { try await AppStore.sync() }
                                                catch { err("Couldn't restore subscription", data: error) }
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)

                                    LabeledContent("If a personal code of support was issued to you, it can be redeemed here.") {
                                        Button("Redeem Code") {
                                            self.isRedeemingCode = true
                                        }
                                    }
                                    .offerCodeRedemption(isPresented: self.$isRedeemingCode) {
                                        if case let .failure(error) = $0 {
                                            err("Couldn't redeem offer code", data: error)
                                        }
                                    }
                                    .padding(.horizontal, 16)

                                    LabeledContent(
                                        """
                                        Spectre is committed to supporting humanitarian concerns in Ukraine.
                                        Residents can use code « SUPPORTUA »
                                        """
                                    ) {
                                        Label { Text("Support Ukraine") } icon: { Text("🇺🇦") }
                                    }
                                    .multilineTextAlignment(.leading)
                                    .padding(.horizontal, 16)
                                }
                            @unknown default: EmptyView()
                        }

                    @unknown default: EmptyView()
                }
            }
        }
        .subscriptionStatusTask(for: StoreSubscription.premium.subscriptionGroupIdentifier) { self.premium = $0 }
        .storeProductsTask(for: StoreProduct.allCases.filter(\.isPublic).map(\.productIdentifier)) { self.products = $0 }
        .labeledContentStyle(.spectreCaptioned)
        .multilineTextAlignment(.center)
        .buttonStyle(.spectreBox())

        // Behaviour
        .popoverTitle("Spectre Premium")
    }

    struct PremiumFeatures: View {
        var body: some View {
            LazyVGrid(columns: [.init(), .init()], spacing: .spectre.padding) {
                LabeledContent("A touch or smile and we can recognize you now. Skip your personal secret.") {
                    Label("Biometric Lock", systemImage: "touchid")
                }
                LabeledContent("Your passwords exactly when you need them, instantly, from any app.") {
                    Label("Auto-Fill", systemImage: "keyboard")
                }
                LabeledContent("Upgrade your inter-site anonymity with unique login names. Who is who?") {
                    Label("Login Name Generator", systemImage: "person.text.rectangle")
                }
                LabeledContent("Say « No » to those pretentiously invasive \"security\" questions.") {
                    Label("Security Answer Generator", systemImage: "person.crop.circle.badge.questionmark.fill")
                }
                LabeledContent("Understand what a password's complexity truly translates into.") {
                    Label("Password Strength", systemImage: "figure.strengthtraining.traditional")
                }
                LabeledContent("Make it yours and dye \(productName) with a dash of personality.") {
                    Label("Application Themes", systemImage: "paintbrush")
                }
                LabeledContent("Universal Clipboard, third‑party storage apps, opening site URLs, etc.") {
                    Label("Advanced Integrations", systemImage: "point.3.connected.trianglepath.dotted")
                }
                LabeledContent("Encourage the development of digital identity initiatives which are open-source & privacy-first.") {
                    Label("Support", systemImage: "heart.text.square")
                }
            }
            .padding(.horizontal, 16)
            .multilineTextAlignment(.leading)
        }
    }
}

#if DEBUG
#Preview {
    Form {
        StoreContent(feature: .biometrics) {
            Button("Hello, World!") {}
        }
    }
    .spectreStyle()
    .task {
        repeat {
            AppConfig.shared.testingPremium = false
            try? await Task.sleep(for: .seconds(3))
            AppConfig.shared.testingPremium = true
            try? await Task.sleep(for: .seconds(3))
        }
        while true
    }
}
#endif
