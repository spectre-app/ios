//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import AsyncAlgorithms
import StoreKit
import SwiftUI

@main
struct SpectreApp: App {
#if canImport(UIKit)
    @UIApplicationDelegateAdaptor
    private var appDelegate: Delegate
#elseif canImport(AppKit)
    @NSApplicationDelegateAdaptor
    private var appDelegate: Delegate
#endif

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .modifier(AppModifier())
                .spectreStyle()
                .modifier(LeakReporter())
        }
    }

    @MainActor
    fileprivate class Delegate: NSObject {
        override init() {
            super.init()
            LeakRegistry.shared.register(self)
        }

#if canImport(UIKit)
        func application(_ application: UIApplication,
                         willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil)
            -> Bool {
            LogSink.shared.register()
            Tracker.shared.startup()
            Migration.shared.perform()
            return true
        }
#elseif canImport(AppKit)
        func applicationWillFinishLaunching(_ notification: Notification) {
            LogSink.shared.register()
            Tracker.shared.startup()
            Migration.shared.perform()
        }
#endif
    }

    private struct AppModifier: ViewModifier {
        @Environment(\.spectre)
        private var spectre: SpectreModel
        @Environment(\.messages)
        private var messages: MessagesModel
        @Environment(\.scenePhase)
        private var scenePhase
        @EnvironmentObject
        private var config: AppConfig
        @Environment(\.requestReview)
        private var requestReview
        @State
        private var deactivated: Date? = .now
#if canImport(UIKit)
        @State
        private var productOverlay: SKOverlay.Configuration?
#endif

        func body(content: Content) -> some View {
            content
                .modify {
                    $0
                    #if canImport(UIKit)
                    .appStoreOverlay(isPresented: self.$productOverlay.isSet()) { self.productOverlay! }
                    #endif
                }
                .confirmationDialog("Keeping Safe", isPresented: self.$config.notificationsDecided.inverse()) {
                    Button("Thanks!") {
                        Task { await Tracker.shared.enableNotifications(userRequested: false) }
                    }
                } message: {
                    Text("""
                        Things move fast in the online world.

                        If you enable notifications, we can inform you of known breaches and keep you current on important security events.
                        """)
                }
                .confirmationDialog("Diagnostics", isPresented: self.$config.diagnosticsDecided.inverse()) {
                    Button("Disable", role: .cancel) {
                        self.config.diagnostics = false
                    }
                    Button("Engage") {
                        self.config.diagnostics = true
                    }
                } message: {
                    Text("""
                        If a bug, crash or issue should happen, Diagnostics will let us know and fix it.

                        It's just code and statistics; personal information is sacred and cannot leave your device.
                        """)
                }

                .overlay {
                    ZStack {
                        if self.deactivated != nil {
                            Image(self.config.appIcon.glyphName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: .spectre.shape / 2)
                                .frame(height: .spectre.shape)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                .background(.thinMaterial)
                                .transition(.blurReplace)
                        }
                    }
                    .animation(.default, value: self.deactivated == nil)
                    .ignoresSafeArea()
                }
                .onChange(of: self.scenePhase, initial: true) {
                    switch self.scenePhase {
                        case .background:
                            self.deactivated = self.deactivated ?? .init()
                            self.spectre.activeUser?.logout()
                        case .inactive:
                            self.deactivated = self.deactivated ?? .init()
                        case .active:
                            if let elapsed = self.deactivated?.timeIntervalSinceNow, -elapsed > .minutes(3) {
                                self.spectre.activeUser?.logout()
                            }
                            self.deactivated = nil
                            // FIXME: update when files change / app foregrounds?
                            Task { await Marshal.shared.updateUserFiles() }
                        @unknown default: ()
                    }
                }

                .onOpenURL { self.open($0) }

                // Monitor StoreKit transactions & keep StoreFeature status up-to-date.
                .task(id: self.config.masterPasswordCustomer) {
                    await updateStoreFeatures()
                }
            #if !PUBLIC
                .task(id: self.config.testingPremium) {
                    await updateStoreFeatures()
                }
            #endif
                .task {
                    for await transaction in Transaction.updates {
                        await updateStoreFeatures(deliver: transaction)
                    }
                }
        }

        private func open(_ url: URL) {
           // Handle <spectre:*> URLs.
           if let components = URLComponents(url: url, resolvingAgainstBaseURL: false), components.scheme == "spectre",
              let action = Action.allCases.first(where: { $0.rawValue == components.path }),
              self.open(action, components: components) {
               return
           }

           // Handle resource URLs that contain Spectre user files.
           let progress = self.messages.start(message: "Importing user")
           let securityScoped = url.startAccessingSecurityScopedResource()
           let urlRead = NSFileAccessIntent.readingIntent(with: url)
           NSFileCoordinator().coordinate(with: [urlRead], queue: .init(queue: .global(qos: .userInitiated))) { error in
               defer {
                   if securityScoped {
                       url.stopAccessingSecurityScopedResource()
                   }
               }

               if let error {
                   err("Couldn't open import", data: url, error)
                   progress.cancel()
                   return
               }

               guard let importData = FileManager.default.contents(atPath: urlRead.url.path)
               else {
                   err("Couldn't read import", data: url, error)
                   progress.cancel()
                   return
               }

               // TODO: In-place editing?
               Task { @MainActor in
                   do {
                       try await self.import(data: importData)
                       inf("Imported user", data: url)
                       progress.completedUnitCount += 1
                   }
                   catch {
                       err("Couldn't import user", data: error)
                   }
               }
           }
        }

        private func open(_ action: Action, components: URLComponents) -> Bool {
            switch action {
                case .import:
                    // spectre:import?data=<export>
                    guard let data = components.queryItems?.first(where: { $0.name == "data" })?.value?.data(using: .utf8)
                    else {
                        wrn("Import URL missing data parameter.", data: components.url)
                        return false
                    }

                    Task {
                        do {
                            try await self.import(data: data)
                            inf("Migrated user")
                        }
                        catch {
                            err("Couldn't migrate user", data: error)
                        }
                    }
                    return true

                case .web:
                    // spectre:web?url=<url>
                    guard components.verifySignature()
                    else {
                        wrn("Tried to open an untrusted URL for action: \(action)", data: components.url)
                        return false
                    }
                    let openString = components.queryItems?.first(where: { $0.name == "url" })?.value ?? "https://spectre.app"
                    guard let openURL = URL(string: openString)
                    else {
                        wrn("Cannot open malformed URL.", data: openString)
                        return false
                    }

                    self.messages.show(url: openURL)
                    return true

                case .review:
                    // spectre:review
                    guard components.verifySignature()
                    else {
                        wrn("Tried to open an untrusted URL for action: \(action)", data: components.url)
                        return false
                    }

                    self.requestReview()
                    return true

                case .update:
                    // spectre:update[?id=<appleid>[&build=<version>]]
                    guard components.verifySignature()
                    else {
                        wrn("Tried to open an untrusted URL for action: \(action)", data: components.url)
                        return false
                    }

                    let id = components.queryItems?.first(where: { $0.name == "id" })?.value ?? "\(productAppleID)"
                    let build = components.queryItems?.first(where: { $0.name == "build" })?.value
                    Task {
                        do {
                            let result = try await self.isUpToDate(appleID: id, buildVersion: build)
                            if result.upToDate {
                                inf(
                                    "Your \(productName) app is up-to-date!",
                                    data: "build[\(result.buildVersion)] > store[\(result.storeVersion)]"
                                )
                            }
                            else {
                                inf(
                                    "\(productName) is outdated",
                                    data: "build[\(result.buildVersion)] < store[\(result.storeVersion)]"
                                )
#if canImport(UIKit)
                                self.productOverlay = SKOverlay.AppConfiguration(appIdentifier: id, position: .bottom)
#endif
                            }
                        }
                        catch {
                            err("Couldn't check for updates", data: error)
                        }
                    }
                    return true

#if canImport(UIKit)
                case .store:
                    // spectre:store[?id=<appleid>,campaignToken=<token>,providerToken=<token>,customProductPageIdentifier=<identifier>]
                    guard components.verifySignature()
                    else {
                        wrn("Tried to open an untrusted URL for action: \(action)", data: components.url)
                        return false
                    }

                    let id = components.queryItems?.first(where: { $0.name == "id" })?.value ?? "\(productAppleID)"
                    let overlay = SKOverlay.AppConfiguration(appIdentifier: id, position: .bottom)
                    (components.queryItems?.first(where: { $0.name == "campaignToken" })?.value).flatMap {
                        overlay.campaignToken = $0
                    }
                    (components.queryItems?.first(where: { $0.name == "providerToken" })?.value).flatMap {
                        overlay.providerToken = $0
                    }
                    (components.queryItems?.first(where: { $0.name == "customProductPageIdentifier" })?.value).flatMap {
                        overlay.customProductPageIdentifier = $0
                    }
                    self.productOverlay = overlay
                    return true
#endif
            }
        }

        private func `import`(data: Data) async throws {
            try await Marshal.shared.import(
                data: data, merge: true,
                needAuthentication: { userFile, error in
                    try await self.messages.promptAuthentication(
                        to: "Unlock Import", for: userFile.userName,
                        previousError: error, action: "Import"
                    )
                },
                didMerge: { _, existingUser, result in
                    if result.userDetails || result.addedSites > .zero || result.replacedSites > .zero {
                        inf("Updated \(existingUser.userName) from import.", data:
                            """
                            Added \(result.addedSites), \
                            updated \(result.replacedSites) sites, \
                            user details \(result.userDetails ? "" : "not ")updated.
                            """
                        )
                    }
                    else {
                        inf("No new changes in import.")
                    }
                }
            )
        }

        private func isUpToDate(appleID: String, buildVersion: String? = nil)
            async throws -> (upToDate: Bool, buildVersion: String, storeVersion: String) {
            guard let country = await Storefront.current?.countryCode,
                  let searchURL = URL(string: "https://itunes.apple.com/lookup?id=\(appleID)&country=\(country)&limit=1")
            else { throw AppError.internal(reason: "No storefront") }

            guard let urlSession = URLSession.required.get()
            else { throw AppError.issue("App is in offline mode") }

            let data = try await urlSession.data(for: URLRequest(url: searchURL)).0
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let error = json?["errorMessage"] as? String {
                throw AppError.issue("iTunes store lookup issue", reason: error)
            }

            guard let metadata = ((json?["results"] as? [Any])?.first as? [String: Any])
            else { throw AppError.issue("Missing iTunes application metadata") }
            guard let storeVersion = metadata["version"] as? String
            else { throw AppError.issue("Missing version in iTunes metadata") }

            let buildVersion = buildVersion ?? productVersion
            return (
                upToDate: !buildVersion.isVersionOutdated(by: storeVersion),
                buildVersion: buildVersion, storeVersion: storeVersion
            )
        }
    }

    private enum Action: String, CaseIterable {
        case `import`, web, review, update
#if canImport(UIKit)
        case store
#endif
    }
}

#if canImport(UIKit)
extension SpectreApp.Delegate: UIApplicationDelegate {}
#elseif canImport(AppKit)
extension SpectreApp.Delegate: NSApplicationDelegate {}
#endif
