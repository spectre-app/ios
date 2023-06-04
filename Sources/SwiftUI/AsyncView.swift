//
//  AsyncView.swift
//  Spectre
//
//  Created by Maarten Billemont on 2023-09-30.
//  Copyright © 2023 Lyndir. All rights reserved.
//

import SwiftUI

public struct AsyncView<Input: Hashable, Output: Sendable>: View {
    var input: Input
    var task: (Input) async throws -> Output
    var content: (Result<Output, Error>?) -> AnyView

    @State
    private var result: Result<Output, Error>?

    public var body: some View {
        self.content(self.result)
            .onChange(of: self.input, initial: true) {
                Task {
                    self.result = await Task {
                        try await self.task(self.input)
                    }.result
                }
            }
    }

    public init(
        onChange input: Input, do task: @escaping (Input) async throws -> Output,
        @ViewBuilder finished: @escaping (Result<Output, Error>?) -> some View
    ) {
        self.input = input
        self.task = task
        self.content = { AnyView(finished($0)) }
    }

    public init(
        onChange input: Input, do task: @escaping (Input) async throws -> Output,
        @ViewBuilder finished: @escaping (Output?) -> some View,
        @ViewBuilder failure: @escaping (Error) -> some View
    ) {
        self.input = input
        self.task = task
        self.content = {
            switch $0 {
                case let .success(value): return AnyView(finished(value))
                case let .failure(error): return AnyView(failure(error))
                case .none: return AnyView(finished(nil))
            }
        }
    }

    public init(
        onChange input: Input, do task: @escaping (Input) async -> Output,
        @ViewBuilder finished: @escaping (Output?) -> some View
    ) {
        self.input = input
        self.task = task
        self.content = { AnyView(finished(try? $0?.get())) }
    }
}

#Preview {
    AsyncView(onChange: "Finished!") {
        try? await Task.sleep(for: .seconds(3))
        return $0
    } finished: {
        Text($0 ?? "Waiting")
    }
}
