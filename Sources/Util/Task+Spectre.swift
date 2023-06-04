//
// Created by Maarten Billemont on 2022-11-14.
// Copyright (c) 2022 Lyndir. All rights reserved.
//

import Foundation
import Combine

public extension Task {
    static func unsafeAwait(task: @escaping () async -> Success) -> Success where Failure == Never {
        let future = Future<Success, Failure> { promise in
            Task<Void, Never>.detached {
                promise( .success( await task() ) )
            }
        }

        let lock = NSLock()
        lock.lock()

        var result: Success?
        let monitor = future.sink(
                receiveCompletion: { _ in lock.unlock() },
                receiveValue: { result = $0 }
        )

        lock.lock()
        monitor.cancel()
        return result!
    }

    static func unsafeAwait(task: @escaping () async throws -> Success) throws -> Success where Failure == Error {
        let future = Future<Success, Failure> { promise in
            Task<Void, Never>.detached {
                do { promise( .success( try await task() ) ) }
                catch { promise( .failure( error ) ) }
            }
        }

        let lock = NSLock()
        lock.lock()

        var result: Success?, error: Failure?
        let monitor = future.sink( receiveCompletion: {
            if case let .failure(failure) = $0 {
                error = failure
            }
            lock.unlock()
        }, receiveValue: { result = $0 } )

        lock.lock()
        if let error = error {
            throw error
        }
        monitor.cancel()
        return result!
    }
}

public extension CheckedContinuation {
    func resume(task: @escaping () async -> T) where E == Never {
        Task.detached {
            self.resume(returning: await task())
        }
    }

    func resume(task: @escaping () async throws -> T) where E == Error {
        Task.detached {
            do {
                self.resume(returning: try await task())
            }
            catch {
                self.resume(throwing: error)
            }
        }
    }
}
