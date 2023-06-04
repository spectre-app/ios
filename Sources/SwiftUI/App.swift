//
//  App.swift
//  Spectre
//
//  Created by Maarten Billemont on 2023-07-08.
//  Copyright © 2023 Lyndir. All rights reserved.
//

import SwiftUI

@Observable public class SpectreModel: UserObserver {
    var activeUser: User? {
        willSet {
            if let activeUser, newValue != activeUser {
                activeUser.observers.unregister(observer: self)
            }
        }
        didSet {
            if let activeUser, oldValue != activeUser {
                activeUser.observers.register(observer: self)
            }
        }
    }

    func loginExistingUser(_ existingUser: Marshal.UserFile, using keyFactory: KeyFactory) async throws {
        activeUser = try await existingUser.authenticate(using: keyFactory)
    }

    func loginNewUser(using keyFactory: KeyFactory) async throws {
        activeUser = try await User(userName: keyFactory.userName).login(using: keyFactory)
    }

    // - UserObserver

    func didLogout(user: User) {
        if activeUser == user {
            activeUser = nil
        }
    }
}

extension EnvironmentValues {
    var spectre: SpectreModel {
        get { self[SpectreModelKey.self] }
        set { self[SpectreModelKey.self] = newValue }
    }

    private struct SpectreModelKey: EnvironmentKey {
        static let defaultValue: SpectreModel = .init()
    }
}

private struct RestoreAnimation: TransactionKey {
    static let defaultValue: Animation? = nil
}

extension Transaction {
    var restoreAnimation: Animation? {
        get { self[RestoreAnimation.self] }
        set { self[RestoreAnimation.self] = newValue }
    }
}

@main
struct SpectreApp: App {
    @Environment(\.spectre)
    private var spectre: SpectreModel

    var body: some Scene {
        WindowGroup {
            ZStack {
                if let activeUser = self.spectre.activeUser {
                    SitesScreen(activeUser: activeUser)
                        .transition(.slide)
                        .zIndex(1)
                } else {
                    LoginScreen()
                        .transition(.opacity)
                        .zIndex(0)
                }
            }
            .animation(.default, value: self.spectre.activeUser)
            .appStyle()
        }
    }
}
