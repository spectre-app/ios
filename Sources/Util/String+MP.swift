//
// Created by Maarten Billemont on 2019-05-13.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

extension String {
    init?(safeUTF8 pointer: UnsafePointer<CChar>?, deallocate: Bool = false) {
        guard let pointer = pointer
        else {
            return nil
        }
        defer {
            if deallocate {
                pointer.deallocate()
            }
        }

        self.init( validatingUTF8: pointer )
    }
}
