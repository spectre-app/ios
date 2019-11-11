//
// Created by Maarten Billemont on 2019-11-08.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

extension NSLayoutConstraint {
    func with(priority: UILayoutPriority) -> Self {
        self.priority = priority
        return self
    }
}
