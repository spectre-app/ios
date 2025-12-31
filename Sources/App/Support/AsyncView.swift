//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import SwiftUI

public struct AsyncView: View {
    let input: AnyHashable
    let progressView: () -> AnyView
    let resultTask: @MainActor () async -> AnyView

    @State
    private var contentView: AnyView?

    public var body: some View {
        ZStack {
            self.contentView
        }
        .task(id: self.input) {
            self.contentView = self.progressView()
            self.contentView = await self.resultTask()
        }
    }

    public init<Input: Hashable & Sendable, Output>(
        onChange input: Input, do task: @escaping (Input) async throws -> Output,
        @ViewBuilder finished: @escaping (Result<Output, Error>?) -> some View,
    ) {
        self.input = input
        self.progressView = { AnyView(finished(nil)) }
        self.resultTask = { await AnyView(finished(Task { try await task(input) }.result)) }
    }

    public init<Input: Hashable, Output>(
        onChange input: Input, do task: @escaping (Input) async throws -> Output,
        @ViewBuilder finished: @escaping (Output?) -> some View,
        @ViewBuilder failure: @escaping (Error) -> some View,
    ) {
        self.input = input
        self.progressView = { AnyView(finished(nil)) }
        self.resultTask = {
            do {
                return try await AnyView(finished(task(input)))
            }
            catch {
                return AnyView(failure(error))
            }
        }
    }

    public init<Input: Hashable, Output>(
        onChange input: Input, do task: @escaping (Input) async -> Output,
        @ViewBuilder finished: @escaping (Output?) -> some View,
    ) {
        self.input = input
        self.progressView = { AnyView(finished(nil)) }
        self.resultTask = { await AnyView(finished(task(input))) }
    }

    public init<Output>(
        do task: @escaping () async throws -> Output,
        @ViewBuilder finished: @escaping (Result<Output, Error>?) -> some View,
    ) {
        self.init(onChange: Int.zero, do: { _ in try await task() }, finished: finished)
    }

    public init<Output>(
        do task: @escaping () async throws -> Output,
        @ViewBuilder finished: @escaping (Output?) -> some View,
        @ViewBuilder failure: @escaping (Error) -> some View,
    ) {
        self.init(onChange: Int.zero, do: { _ in try await task() }, finished: finished, failure: failure)
    }

    public init<Output>(
        do task: @escaping () async -> Output,
        @ViewBuilder finished: @escaping (Output?) -> some View,
    ) {
        self.init(onChange: Int.zero, do: { _ in await task() }, finished: finished)
    }
}

struct AsyncView_Previews: View, PreviewProvider {
    static var previews: some View = Self()

    @State
    private var count = 0.0

    var body: some View {
        VStack {
            Button("\(self.count)") { self.count += 1 }

            AsyncView(onChange: self.count) {
                try? await Task.sleep(for: .seconds(3))
                return "\($0 + 0.1)"
            } finished: {
                Text($0 ?? "Waiting")
            }
        }
    }
}
