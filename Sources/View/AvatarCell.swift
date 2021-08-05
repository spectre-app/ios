// =============================================================================
// Created by Maarten Billemont on 2019-03-31.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import UIKit

class AvatarCell: EffectCell {
    public var avatar: User.Avatar = .avatar_0 {
        didSet {
            DispatchQueue.main.perform {
                self.avatarImage.image = self.avatar.image
            }
        }
    }

    private let avatarImage = UIImageView()

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override init(frame: CGRect) {
        super.init( frame: frame )

        self.avatarImage.contentMode = .scaleAspectFill
        self.effectView.isCircular = false
        self.effectView.rounding = 20
        self.effectView.borderWidth = 1
        self.effectView.addContentView( self.avatarImage )

        LayoutConfiguration( view: self.avatarImage )
                .constrain( as: .box )
                .constrain { $1.heightAnchor.constraint( equalToConstant: 150 ) }
                .activate()
    }
}
