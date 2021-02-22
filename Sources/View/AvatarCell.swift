//
// Created by Maarten Billemont on 2019-03-31.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

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

        self.effectView.addContentView( self.avatarImage )

        LayoutConfiguration( view: self.avatarImage )
                .constrain( as: .box, margin: true ).activate()
    }
}
