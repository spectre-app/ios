//
// Created by Maarten Billemont on 2020-10-08.
// Copyright (c) 2020 Lyndir. All rights reserved.
//

import Foundation
import AuthenticationServices

class AutoFillModel: MPMarshalObserver {
    static let shared = AutoFillModel()

    var users     = [ MPUser ]()
    var userFiles = [ MPMarshal.UserFile ]()
    var context   = Context()

    init() {
        do { self.userFiles = try MPMarshal.shared.setNeedsUpdate().await() }
        catch { err( "Cannot read user documents: %@", error ) }

        MPMarshal.shared.observers.register( observer: self )
    }

    // MARK: --- MPMarshalObserver ---

    func userFilesDidChange(_ userFiles: [MPMarshal.UserFile]) {
        self.userFiles = userFiles

        for userFile in self.userFiles {
            self.users.removeAll( where: { userFile.fullName == $0.fullName && userFile.hasChanges( from: $0 ) } )
        }
    }

    // MARK: --- Types ---

    struct Context {
        var serviceIdentifiers: [ASCredentialServiceIdentifier]? = nil
        var credentialIdentity: ASPasswordCredentialIdentity?    = nil
    }
}
