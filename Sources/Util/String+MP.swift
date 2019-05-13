//
// Created by Maarten Billemont on 2019-05-13.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

extension String {
    init?(safeUtf8String string: UnsafePointer<CChar>?) {
        guard let string = string
        else {
            return nil
        }

        self.init( utf8String: string )
    }
}
