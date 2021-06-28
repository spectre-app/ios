//==============================================================================
// Created by Maarten Billemont on 2020-09-13.
// Copyright (c) 2020 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
//==============================================================================

import UIKit

#if DEBUG
class WTFLabel: UILabel {
    override var isHidden: Bool {
        get {
            super.isHidden
        }
        set {
            super.isHidden = newValue
        }
    }
}
#endif
