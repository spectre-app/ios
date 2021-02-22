//
// Created by Maarten Billemont on 2020-10-08.
// Copyright (c) 2020 Lyndir. All rights reserved.
//

import Foundation
import AuthenticationServices

class AutoFillModel: MarshalObserver {
    static let shared = AutoFillModel()

    var users     = [ User ]()
    var userFiles = [ Marshal.UserFile ]()
    var context   = Context()

    init() {
        do { self.userFiles = try Marshal.shared.setNeedsUpdate().await() }
        catch { err( "Cannot read user documents: %@", error ) }

        Marshal.shared.observers.register( observer: self )
    }

    // MARK: --- MarshalObserver ---

    func userFilesDidChange(_ userFiles: [Marshal.UserFile]) {
        self.userFiles = userFiles

        for userFile in self.userFiles {
            self.users.removeAll( where: { $0.userName == userFile.userName && $0 != userFile } )
        }
    }

    // MARK: --- Types ---

    struct Context {
        var serviceIdentifiers: [ASCredentialServiceIdentifier]? = nil
        var credentialIdentity: ASPasswordCredentialIdentity?    = nil
    }
}
