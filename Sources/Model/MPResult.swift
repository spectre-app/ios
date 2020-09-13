//
// Created by Maarten Billemont on 2020-09-13.
// Copyright (c) 2020 Lyndir. All rights reserved.
//

import Foundation

public protocol MPResult {

    func result(for name: String?, counter: MPCounterValue?, keyPurpose: MPKeyPurpose, keyContext: String?,
                       resultType: MPResultType?, resultParam: String?, algorithm: MPAlgorithmVersion?)
                    -> Promise<(token: String?, counter: MPCounterValue, purpose: MPKeyPurpose, type: MPResultType, algorithm: MPAlgorithmVersion)>

    func state(for name: String?, counter: MPCounterValue?, keyPurpose: MPKeyPurpose, keyContext: String?,
                      resultType: MPResultType?, resultParam: String, algorithm: MPAlgorithmVersion?)
                    -> Promise<(token: String?, counter: MPCounterValue, purpose: MPKeyPurpose, type: MPResultType, algorithm: MPAlgorithmVersion)>

    func copy(for name: String?, counter: MPCounterValue?, keyPurpose: MPKeyPurpose, keyContext: String?,
                     resultType: MPResultType?, resultParam: String?, algorithm: MPAlgorithmVersion?,
                     by host: UIView?) -> Promise<(token: String?, counter: MPCounterValue, purpose: MPKeyPurpose, type: MPResultType, algorithm: MPAlgorithmVersion)>
}
