// =============================================================================
// Created by Maarten Billemont on 2020-10-08.
// Copyright (c) 2020 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import Foundation
import AuthenticationServices

class AutoFillModel: MarshalObserver {
    static let shared = AutoFillModel()

    private var usersCache  = Cache<NSString, User>(named: "AutoFill")
    private var cachedUsers = Set<String>()

    lazy var context = Context()

    init() {
        Marshal.shared.observers.register( observer: self )
    }

    func cachedUser(userName: String?) -> User? {
        userName.flatMap { self.usersCache[$0 as NSString] }
    }

    func cacheUser(_ user: User) {
        self.usersCache[user.userName as NSString] = user
        self.cachedUsers.insert( user.userName )
    }

    // MARK: - MarshalObserver

    func didChange(userFiles: [Marshal.UserFile]) {
        // Purge cached users that have: changed, disappeared, or have disabled autofill.
        self.cachedUsers
            .filter { userName in
                guard let userFile = userFiles.first( where: { $0.autofill && $0.userName == userName } )
                else { return true }
                guard let cachedUser = self.usersCache[userFile.userName as NSString]
                else { return true }
                return cachedUser != userFile
            }
            .forEach {
                self.usersCache[$0 as NSString] = nil
                self.cachedUsers.remove( $0 )
            }
    }

    // MARK: - Types

    struct Context {
        var serviceIdentifiers: [ASCredentialServiceIdentifier]?
        var credentialIdentity: ASPasswordCredentialIdentity?
    }
}
