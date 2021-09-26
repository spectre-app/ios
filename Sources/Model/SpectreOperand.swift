// =============================================================================
// Created by Maarten Billemont on 2020-09-13.
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

public protocol SpectreOperand {

    func use()

    func result(for name: String?, counter: SpectreCounter?, keyPurpose: SpectreKeyPurpose, keyContext: String?,
                resultType: SpectreResultType?, resultParam: String?, algorithm: SpectreAlgorithm?, operand: SpectreOperand?)
                    -> SpectreOperation?

    func state(for name: String?, counter: SpectreCounter?, keyPurpose: SpectreKeyPurpose, keyContext: String?,
               resultType: SpectreResultType?, resultParam: String, algorithm: SpectreAlgorithm?, operand: SpectreOperand?)
                    -> SpectreOperation?
}

public struct SpectreOperation {
    let siteName:  String
    let counter:   SpectreCounter
    let purpose:   SpectreKeyPurpose
    let type:      SpectreResultType
    let algorithm: SpectreAlgorithm
    let operand:   SpectreOperand
    let token:     Promise<String>

    @discardableResult
    public func then(on queue: DispatchQueue? = nil, _ consumer: @escaping (Result<(SpectreOperation, String), Error>) -> Void)
                    -> Promise<(SpectreOperation, String)> {
        Promise( .success( self ) ).and( self.token ).then( on: queue, consumer )
    }

    @discardableResult public func copy(fromView view: UIView, trackingFrom: String) -> Promise<(SpectreOperation, String)> {
        let event = Tracker.shared.begin( track: .subject( "site", action: "use" ) )

        return self.token.promise { token in
            Feedback.shared.play( .trigger )

            UIPasteboard.general.setObjects(
                    [ token as NSString ], localOnly: !AppConfig.shared.allowHandoff, expirationDate: Date( timeIntervalSinceNow: 3 * 60 ) )
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
                          "entropy": Attacker.entropy( type: operation.type ) ?? Attacker.entropy( string: token ),
                        ] )
            }
            catch {
                event.end(
                        [ "result": $0.name,
                          "from": trackingFrom,
                          "action": "copy",
                          "error": error.localizedDescription,
                        ] )
            }
        }
    }
}
