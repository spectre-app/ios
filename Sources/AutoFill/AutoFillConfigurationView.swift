//==============================================================================
// Created by Maarten Billemont on 2021-03-22.
// Copyright (c) 2021 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
//==============================================================================

import UIKit

class AutoFillConfigurationView: UIScrollView {

    let stackView     = UIStackView()
    let messageLabel  = UILabel()
    let step1Title    = UILabel()
    let step2Title    = UILabel()
    let step3Title    = UILabel()
    let settingsImage = ImageView( image: UIImage( named: "autofill-disable-others" ) )
    let appImage      = EffectButton( image: UIImage( named: "icon" ), background: false, square: true, circular: false, rounding: 22 )
    let avatarImage   = EffectButton( image: UIImage( named: "avatar-0" ), border: 0, background: false, square: true, circular: false )
    let userImage     = EffectButton( title: "RLM" )
    let autofillImage = EffectToggleButton( action: { _ in nil } )

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(fromSettings: Bool) {
        super.init( frame: .zero )

        // - View
        self.messageLabel => \.font => Theme.current.font.callout
        self.messageLabel => \.textColor => Theme.current.color.secondary
        self.messageLabel.numberOfLines = 0
        self.messageLabel.textAlignment = .center
        self.messageLabel.text =
                """
                To begin, activate the AutoFill setting for the Spectre user you want to use.
                """

        self.step1Title => \.font => Theme.current.font.headline
        self.step1Title.numberOfLines = 0
        self.step1Title.textAlignment = .center
        self.step1Title.text = "Other AutoFill providers may cause confusion"

        self.step2Title => \.font => Theme.current.font.headline
        self.step2Title.numberOfLines = 0
        self.step2Title.textAlignment = .center
        self.step2Title.text = "Open Spectre and sign into your user"

        self.step3Title => \.font => Theme.current.font.headline
        self.step3Title.numberOfLines = 0
        self.step3Title.textAlignment = .center
        self.step3Title.text = "Tap your user initials and turn on AutoFill"

        self.settingsImage.preservesImageRatio = true
        self.appImage.padded = false
        self.autofillImage.image = .icon( "" )
        self.autofillImage.isSelected = true

        self.stackView.axis = .vertical
        self.stackView.spacing = 8
        self.stackView.alignment = .center
        self.stackView.addArrangedSubview( self.messageLabel )
        self.stackView.addArrangedSubview( MarginView( space: CGSize( width: 24, height: 24 ) ) )
        if fromSettings {
            self.stackView.addArrangedSubview( self.step1Title )
            self.stackView.addArrangedSubview( self.settingsImage )
            self.stackView.addArrangedSubview( MarginView( space: CGSize( width: 4, height: 4 ) ) )
        }
        self.stackView.addArrangedSubview( self.step2Title )
        let step2Steps = UIStackView( arrangedSubviews: [ MarginView( for: self.appImage, anchor: .center ),
                                                          MarginView( for: UIImageView( image: .icon( "" ) ), anchor: .center ),
                                                          MarginView( for: self.avatarImage, anchor: .center ) ],
                                      alignment: .center, distribution: .fillEqually, spacing: 8 )
        self.stackView.addArrangedSubview( step2Steps )
        self.stackView.addArrangedSubview( MarginView( space: CGSize( width: 4, height: 4 ) ) )
        self.stackView.addArrangedSubview( self.step3Title )
        let step3Steps = UIStackView( arrangedSubviews: [ MarginView( for: self.userImage, anchor: .center ),
                                                          MarginView( for: UIImageView( image: .icon( "" ) ), anchor: .center ),
                                                          MarginView( for: self.autofillImage, anchor: .center ) ],
                                      alignment: .center, distribution: .fillEqually, spacing: 8 )
        self.stackView.addArrangedSubview( step3Steps )

        // - Hierarchy
        self.addSubview( self.stackView )

        // - Layout
        LayoutConfiguration( view: self.appImage )
                .constrain { $1.widthAnchor.constraint( equalToConstant: 60 ) }
                .activate()
        LayoutConfiguration( view: self.avatarImage )
                .constrain { $1.widthAnchor.constraint( equalToConstant: 60 ) }
                .activate()
        LayoutConfiguration( view: self.stackView )
                .constrain { $1.widthAnchor.constraint( equalTo: $0.widthAnchor ) }
                .constrain( as: .center, to: self.contentLayoutGuide )
                .activate()
        LayoutConfiguration( view: step3Steps )
                .constrain { $1.widthAnchor.constraint( equalTo: step2Steps.widthAnchor ) }
                .activate()
    }
}
