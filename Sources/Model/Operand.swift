//
// Created by Maarten Billemont on 2020-09-13.
// Copyright (c) 2020 Lyndir. All rights reserved.
//

import Foundation

public protocol Operand {

    func use()

    func result(for name: String?, counter: SpectreCounter?, keyPurpose: SpectreKeyPurpose, keyContext: String?,
                resultType: SpectreResultType?, resultParam: String?, algorithm: SpectreAlgorithm?, operand: Operand?)
                    -> Operation

    func state(for name: String?, counter: SpectreCounter?, keyPurpose: SpectreKeyPurpose, keyContext: String?,
               resultType: SpectreResultType?, resultParam: String, algorithm: SpectreAlgorithm?, operand: Operand?)
                    -> Operation
}

public struct Operation {
    let siteName:  String
    let counter:   SpectreCounter
    let purpose:   SpectreKeyPurpose
    let type:      SpectreResultType
    let algorithm: SpectreAlgorithm
    let operand:   Operand
    let token:     Promise<String>

    @discardableResult
    public func then(on queue: DispatchQueue? = nil, _ consumer: @escaping (Result<(Operation, String), Error>) -> Void)
                    -> Promise<(Operation, String)> {
        Promise( .success( self ) ).and( self.token ).then( on: queue, consumer )
    }

    @discardableResult public func copy(fromView view: UIView, trackingFrom: String) -> Promise<(Operation, String)> {
        let event = Tracker.shared.begin( track: .subject( "site", action: "use" ) )

        return self.token.promise { token in
            Feedback.shared.play( .trigger )

            UIPasteboard.general.setItems(
                    [ [ UIPasteboard.typeAutomatic: token ] ],
                    options: [
                        UIPasteboard.OptionsKey.localOnly: true,
                        UIPasteboard.OptionsKey.expirationDate: Date( timeIntervalSinceNow: 3 * 60 )
                    ] )
            self.operand.use()

            AlertController( title: "Copied \(self.purpose) (3 min)", message: self.siteName, details:
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
                          "entropy": Attacker.entropy( type: operation.type ) ?? Attacker.entropy( string: token ) ?? 0,
                        ] )
            }
            catch {
                event.end(
                        [ "result": $0.name,
                          "from": trackingFrom,
                          "action": "copy",
                          "error": error.localizedDescription
                        ] )
            }
        }
    }
}
