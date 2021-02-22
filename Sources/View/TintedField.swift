//
// Created by Maarten Billemont on 2019-07-05.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class TintedField: UITextField {
    override func tintColorDidChange() {
        super.tintColorDidChange()

        self.textColor = self.tintColor
    }
}
