//
// Created by Maarten Billemont on 2020-09-13.
// Copyright (c) 2020 Lyndir. All rights reserved.
//

import Foundation

public protocol MPOperand {

    func result(for name: String?, counter: MPCounterValue?, keyPurpose: MPKeyPurpose, keyContext: String?,
                resultType: MPResultType?, resultParam: String?, algorithm: MPAlgorithmVersion?)
                    -> MPOperation

    func state(for name: String?, counter: MPCounterValue?, keyPurpose: MPKeyPurpose, keyContext: String?,
               resultType: MPResultType?, resultParam: String, algorithm: MPAlgorithmVersion?)
                    -> MPOperation
}

public struct MPOperation {
    let serviceName: String
    let counter:     MPCounterValue
    let purpose:     MPKeyPurpose
    let type:        MPResultType
    let algorithm:   MPAlgorithmVersion
    let token:       Promise<String>

    @discardableResult
    public func then(on queue: DispatchQueue? = nil, _ consumer: @escaping (Result<(MPOperation, String), Error>) -> Void)
                    -> Promise<(MPOperation, String)> {
        Promise( .success( self ) ).and( self.token ).then( on: queue, consumer )
    }

    public func copy(from view: UIView) -> Promise<(MPOperation, String)> {
        self.token.promise { token in
            MPFeedback.shared.play( .trigger )

            UIPasteboard.general.setItems(
                    [ [ UIPasteboard.typeAutomatic: token ] ],
                    options: [
                        UIPasteboard.OptionsKey.localOnly: true,
                        UIPasteboard.OptionsKey.expirationDate: Date( timeIntervalSinceNow: 3 * 60 )
                    ] )

            MPAlert( title: "Copied \(self.purpose) (3 min)", message: self.serviceName, details:
            """
            Your \(self.purpose) for \(self.serviceName) is:
            \(token)

            It was copied to the pasteboard, you can now switch to your application and paste it into the \(self.purpose) field.

            Note that after 3 minutes, the \(self.purpose) will expire from the pasteboard for security reasons.
            """ ).show( in: view )

            return (self, token)
        }
    }
}
