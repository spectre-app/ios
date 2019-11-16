//
// Created by Maarten Billemont on 2019-11-15.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

extension Result {
    var name: String {
        switch self {
            case .success:
                return "success"
            case .failure:
                return "failure"
        }
    }
}
