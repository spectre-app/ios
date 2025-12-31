//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import SwiftUI

@Observable
final class MessagesModel {
    static var shared = MessagesModel()
    private init() {
        Task {
            for await record in logRecords.values where record.level <= .info {
                let error = record.data.compactMap { $0 as? Error }.first
                if let tracking = record.action?.tracking {
                    MessagesModel.shared.show(message: tracking.description, description: record.message, error: error)
                }
                else {
                    MessagesModel.shared.show(message: "Internal \(record.level.description)", description: record.message, error: error)
                }
            }
        }
    }

    fileprivate var activePage: URL?
    fileprivate var currentMessages: [Message] = []
    fileprivate var currentActivities: [Activity] = []
    fileprivate var currentPrompt: Prompt?
    fileprivate var authenticationRequest: MessagesHost.AuthenticationValue?

    func show(url: URL?) {
        self.activePage = url
    }

    @discardableResult
    func show(message: String, description: String? = nil, error: Error? = nil) -> Message {
        using(Message(title: message, description: description, error: error)) {
            self.currentMessages += [$0]
        }
    }

    @discardableResult
    func start(message: String, description: String? = nil, amount: Int64? = nil,
               isForCurrent: Bool = false, userInfo: [ProgressUserInfoKey: Any]? = nil)
        -> Progress {
        using(Progress(parent: isForCurrent ? .current() : nil, userInfo: userInfo)) {
            if let amount {
                $0.totalUnitCount = amount
            }
            self.currentActivities += [Activity(title: message, description: description, progress: $0)]
        }
    }

    @discardableResult
    func prompt<V: Hashable>(message: String, description: String? = nil, error: Error? = nil,
                             options: [(value: V, description: String)], decision: @escaping (V) -> Void)
        -> Prompt {
        using(Prompt(
            message: Message(title: message, description: description, error: error),
            options: options.map { option in
                Prompt.Option(id: option.value, description: option.description) {
                    decision(option.value)
                }
            }
        )) {
            self.currentPrompt = $0
        }
    }

    func promptAuthentication(to reason: String, for userName: String? = nil, previousError: Error? = nil, action: String) async throws
        -> KeyFactory {
        try await withCheckedThrowingContinuation {
            self.authenticationRequest = .init(
                reason: reason, userName: userName, previousError: previousError, action: action, continuation: $0
            )
        }
    }

    struct Message: Identifiable {
        let moment: Date = .init()
        let title: String
        var description: String?
        var error: Error?

        // - Identifiable

        var id: AnyHashable {
            self.moment
        }
    }

    struct Prompt: Identifiable {
        let message: Message
        let options: [Option]

        // - Identifiable

        var id: AnyHashable {
            self.message.id
        }

        struct Option: Identifiable {
            var id: AnyHashable
            var description: String
            var choose: () -> Void
        }
    }

    struct Activity: Identifiable {
        let moment: Date = .init()
        let title: String
        let description: String?
        var progress: Progress

        // - Identifiable

        var id: AnyHashable {
            self.moment
        }
    }
}

extension EnvironmentValues {
    var messages: MessagesModel {
        get { self[MessagesModelKey.self] }
        set { self[MessagesModelKey.self] = newValue }
    }

    private struct MessagesModelKey: EnvironmentKey {
        static let defaultValue: MessagesModel = .shared
    }
}

struct MessagesHost: ViewModifier {
    @State
    private var messages: MessagesModel = .shared

    func body(content: Content) -> some View {
        ZStack {
            content

            if let progress = Progress.current() {
                ProgressView(progress)
            }

            VStack {
                ForEach(self.messages.currentMessages) {
                    MessageView(message: $0)
                }
                ForEach(self.messages.currentActivities) {
                    ActivityView(activity: $0)
                }

                Spacer()
            }
            .padding(.horizontal, .spectre.margin)
            .animation(.default, value: self.messages.currentMessages.map(\.id))
            .modifier(CurrentPromptDialog(messages: self.messages))
        }
        .modifier(AuthenticationRequestAlert(messages: self.messages))
        .modify {
            $0
            #if canImport(UIKit)
            .fullScreenCover(item: self.$messages.activePage) {
                WebView(url: $0).ignoresSafeArea()
            }
            #endif
        }
        .environment(\.messages, self.messages)
    }

    struct AuthenticationValue {
        let reason: String
        let userName: String?
        let previousError: Error?
        let action: String
        let continuation: CheckedContinuation<KeyFactory, Error>
    }

    private struct MessageView: View {
        let message: MessagesModel.Message

        @Environment(\.messages)
        private var messages: MessagesModel
        @State
        private var isSticky = false

        var body: some View {
            GroupBox(self.message.title) {
                self.message.description.flatMap(Text.init)?
                    .lineLimit(self.isSticky ? nil : 1)
                    .font(self.isSticky ? .spectre.callout : .spectre.caption1)

                if let error = self.message.error?.details {
                    Divider()

                    Text(error.description)
                        .lineLimit(self.isSticky ? nil : 1)
                        .font(self.isSticky ? .spectre.callout : .spectre.caption1)
                    error.suggestion.flatMap(Text.init)?
                        .font(self.isSticky ? .spectre.caption1 : .spectre.caption2)
                        .foregroundStyle(Color.spectre.alternative)

                    if self.isSticky {
                        error.failure.flatMap(Text.init)?
                            .font(.spectre.caption2)

                        ForEach(error.underlying, id: \.self) {
                            Text($0)
                                .font(.spectre.footnote)
                                .foregroundStyle(Color.spectre.alternative)
                        }
                    }
                }
            }
            .groupBoxStyle(.spectre(with: {
                Rectangle().fill(.ultraThickMaterial).opacity(self.isSticky ? .on : .long)
            }))
            .overlay(alignment: .topTrailing) {
                if self.isSticky {
                    Image(systemName: "xmark.circle")
                        .padding(.spectre.padding)
                }
            }
            .onTapGesture {
                if self.isSticky {
                    self.removeMessage()
                }
                else {
                    self.isSticky = true
                }
            }
            .task {
                try? await Task.sleep(for: .seconds(3))

                if !self.isSticky {
                    self.removeMessage()
                }
            }
        }

        func removeMessage() {
            self.messages.currentMessages.removeAll { $0.id == self.message.id }
        }
    }

    private struct ActivityView: View {
        @State
        var activity: MessagesModel.Activity

        @Environment(\.messages)
        private var messages: MessagesModel
        @State
        private var isActive = false
        @State
        private var isFinished = false

        var body: some View {
            GroupBox(self.activity.title) {
                self.activity.description.flatMap(Text.init)?
                    .font(.spectre.callout)

                Divider()

                Group {
                    if self.isFinished {
                        Image(systemName: "checkmark")
                    }
                    else if self.activity.progress.totalUnitCount <= .zero {
                        ProgressView(self.activity.progress)
                            .progressViewStyle(.circular)
                    }
                    else {
                        ProgressView(self.activity.progress)
                    }
                }
                .font(self.isActive ? .spectre.callout : .spectre.caption1)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .groupBoxStyle(.spectre(with: {
                if self.isFinished {
                    Color.spectre.placeholder
                }
                else if self.isActive {
                    Color.spectre.selection
                }
                else {
                    Color.clear
                }
            }))
            .overlay(alignment: .topTrailing) {
                if self.isActive {
                    Image(systemName: "xmark.circle")
                        .padding(.spectre.padding)
                }
            }
            .animation(.default, value: [self.isActive, self.isFinished] as AnyHashable)
            .onTapGesture {
                if self.isActive {
                    self.removeMessage()
                }
                else {
                    self.isActive = true
                }
            }
            .onReceive(self.activity.progress.publisher(for: \.isFinished)) {
                self.isFinished = $0
            }
            .onChange(of: self.isFinished) {
                if self.isFinished {
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        if !self.isActive {
                            self.removeMessage()
                        }
                    }
                }
            }
        }

        func removeMessage() {
            self.messages.currentActivities.removeAll { $0.id == self.activity.id }
        }
    }

    struct CurrentPromptDialog: ViewModifier {
        @State
        fileprivate var messages: MessagesModel

        func body(content: Content) -> some View {
            content.confirmationDialog(
                Text(self.messages.currentPrompt?.message.title ?? ""),
                isPresented: self.$messages.currentPrompt.isSet(), presenting: self.messages.currentPrompt
            ) {
                ForEach($0.options) { option in
                    Button(option.description) {
                        option.choose()
                    }
                }
            } message: { prompt in
                Text(
                    """
                    \(prompt.message.title)\
                    \(let: prompt.message.description, "\n{}")\
                    \(let: prompt.message.error?.details.description, "\n{}")\
                    \(let: prompt.message.error?.details.failure, "\n\n{}")\
                    \(let: prompt.message.error?.details.underlying.joined(separator: "\n").nonEmpty, "\n{}")\
                    \(let: prompt.message.error?.details.suggestion, "\n\n{}")
                    """
                )
            }
        }
    }

    struct AuthenticationRequestAlert: ViewModifier {
        @State
        fileprivate var messages: MessagesModel
        @State
        private var userName = ""
        @State
        private var secret = ""

        func body(content: Content) -> some View {
            content.alert(
                self.messages.authenticationRequest?.reason ?? "Authentication",
                isPresented: self.$messages.authenticationRequest.isSet(),
                presenting: self.messages.authenticationRequest
            ) { authenticationRequest in
                if authenticationRequest.userName == nil {
                    TextField(prompt: "Full name", text: self.$userName)
                        .submitLabel(.done)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                        .modify {
                            $0
                            #if canImport(UIKit)
                            .textInputAutocapitalization(.words)
                            .keyboardType(.alphabet)
                            #endif
                        }
                }
                SecureField(prompt: "Spectre secret", text: self.$secret)

                Button("Cancel", role: .cancel) {
                    authenticationRequest.continuation.resume(throwing: CancellationError())
                }
                Button(authenticationRequest.action) {
                    authenticationRequest.continuation.resume(returning: SecretKeyFactory(
                        userName: authenticationRequest.userName ?? self.userName,
                        userSecret: self.secret
                    ))
                }
            } message: { authenticationRequest in
                if let previousError = authenticationRequest.previousError {
                    Text(previousError.localizedDescription)
                }

                if let userName = authenticationRequest.userName {
                    Text("Enter the Spectre secret for \(userName)")
                }
                else {
                    Text("Enter your name and Spectre secret")
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    Preview()
        .spectreStyle()
}

private struct Preview: View {
    @Environment(\.messages)
    private var messages: MessagesModel

    var body: some View {
        Path().task {
            self.messages.show(message: "title")
            self.messages.show(message: "title", description: "description")
            self.messages.show(
                message: "title", description: "description",
                error: AppError.issue("Issue", reason: "Reason", suggestion: "Suggestion", cause: errSecAllocate)
            )
            let progress = self.messages.start(message: "Running the progress", description: "description")
            self.messages.prompt(
                message: "Complete the progress?", description: "third",
                error: AppError.internal(reason: "Reason", details: "Details"),
                options: [
                    (true, "Yes"),
                    (false, "No"),
                ]
            ) { progress.completedUnitCount = $0 ? 1 : 0 }
        }
    }
}
#endif
