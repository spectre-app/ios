//
// Created by Maarten Billemont on 2020-09-13.
// Copyright (c) 2020 Lyndir. All rights reserved.
//

import Foundation

public protocol MPOperand {

    func use()

    func result(for name: String?, counter: MPCounterValue?, keyPurpose: MPKeyPurpose, keyContext: String?,
                resultType: MPResultType?, resultParam: String?, algorithm: MPAlgorithmVersion?, operand: MPOperand?)
                    -> MPOperation

    func state(for name: String?, counter: MPCounterValue?, keyPurpose: MPKeyPurpose, keyContext: String?,
               resultType: MPResultType?, resultParam: String, algorithm: MPAlgorithmVersion?, operand: MPOperand?)
                    -> MPOperation
}

public struct MPOperation {
    let siteName: String
    let counter:     MPCounterValue
    let purpose:     MPKeyPurpose
    let type:        MPResultType
    let algorithm:   MPAlgorithmVersion
    let operand:     MPOperand
    let token:       Promise<String>

    @discardableResult
    public func then(on queue: DispatchQueue? = nil, _ consumer: @escaping (Result<(MPOperation, String), Error>) -> Void)
                    -> Promise<(MPOperation, String)> {
        Promise( .success( self ) ).and( self.token ).then( on: queue, consumer )
    }

    @discardableResult public func copy(fromView view: UIView, trackingFrom: String) -> Promise<(MPOperation, String)> {
        let event = MPTracker.shared.begin( track: .subject( "site", action: "use" ) )

        return self.token.promise { token in
            MPFeedback.shared.play( .trigger )

            UIPasteboard.general.setItems(
                    [ [ UIPasteboard.typeAutomatic: token ] ],
                    options: [
                        UIPasteboard.OptionsKey.localOnly: true,
                        UIPasteboard.OptionsKey.expirationDate: Date( timeIntervalSinceNow: 3 * 60 )
                    ] )
            self.operand.use()

            MPAlert( title: "Copied \(self.purpose) (3 min)", message: self.siteName, details:
            """
            Your \(self.purpose) for \(self.siteName) is:
            \(token)

            It was copied to the pasteboard, you can now switch to your application and paste it into the \(self.purpose) field.

            Note that after 3 minutes, the \(self.purpose) will expire from the pasteboard for security reasons.
            """ ).show( in: view )

            return (self, token)
        }.then {
            do {
                let (operation, token) = try $0.get()
                event.end(
                        [ "result": $0.name,
                          "from": trackingFrom,
                          "action": "copy",
                          "counter": "\(operation.counter)",
                          "purpose": "\(operation.purpose)",
                          "type": "\(operation.type)",
                          "algorithm": "\(operation.algorithm)",
                          "entropy": MPAttacker.entropy( type: operation.type ) ?? MPAttacker.entropy( string: token ) ?? 0,
                        ] )
            }
            catch {
                event.end( [ "result": $0.name, "from": trackingFrom, "error": error.localizedDescription ] )
            }
        }
    }
}
