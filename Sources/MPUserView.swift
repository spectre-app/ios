//
// Created by Maarten Billemont on 2018-03-04.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class MPUserView: UIView {

    let avatarView = MPUserAvatarView()

    override init(frame: CGRect) {
        super.init( frame: frame )

        self.addSubview( self.avatarView )
    }

    required init?(coder aDecoder: NSCoder) {
        super.init( coder: aDecoder )
    }

    class MPUserAvatarView : UIView {
    }
}
