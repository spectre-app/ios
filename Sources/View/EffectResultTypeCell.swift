//==============================================================================
// Created by Maarten Billemont on 2019-03-31.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
//==============================================================================

import UIKit

class EffectClassifiedCell: EffectCell, Updatable {
    private let separatorView = UIView()
    private let nameLabel     = UILabel()
    private let classLabel    = UILabel()
    private lazy var stackView = UIStackView( arrangedSubviews: [ self.nameLabel, self.separatorView, self.classLabel ] )

    var name:    String? {
        didSet {
            self.updateTask.request()
        }
    }
    var `class`: String? {
        didSet {
            self.updateTask.request()
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override init(frame: CGRect) {
        super.init( frame: frame )

        self.separatorView => \.backgroundColor => Theme.current.color.secondary

        self.nameLabel.textAlignment = .center
        self.nameLabel.allowsDefaultTighteningForTruncation = true
        self.nameLabel => \.textColor => Theme.current.color.body
        self.nameLabel => \.font => Theme.current.font.headline

        self.classLabel.textAlignment = .center
        self.classLabel.allowsDefaultTighteningForTruncation = true
        self.classLabel => \.textColor => Theme.current.color.body
        self.classLabel => \.font => Theme.current.font.caption1

        self.stackView.axis = .vertical

        self.effectView.addContentView( self.stackView )

        LayoutConfiguration( view: self.stackView )
                .constrain { $1.topAnchor.constraint( greaterThanOrEqualTo: $0.layoutMarginsGuide.topAnchor ) }
                .constrain { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                .constrain { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                .constrain { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.layoutMarginsGuide.bottomAnchor ) }
                .constrain { $1.centerYAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerYAnchor ) }
                .activate()
        LayoutConfiguration( view: self.separatorView )
                .constrain { $1.heightAnchor.constraint( equalToConstant: 1 ) }
                .constrain { $1.centerYAnchor.constraint( equalTo: self.stackView.centerYAnchor ) }
                .activate()
    }

    // MARK: --- Updatable ---

    lazy var updateTask = DispatchTask.update( self ) { [weak self] in
        guard let self = self
        else { return }

        self.nameLabel.text = self.name
        self.classLabel.text = self.class
        self.nameLabel.isHidden = self.name?.isEmpty ?? true
        self.classLabel.isHidden = self.class?.isEmpty ?? true
        self.separatorView.isHidden = self.nameLabel.isHidden || self.classLabel.isHidden
        self.nameLabel.numberOfLines = self.separatorView.isHidden ? 0: 1
        self.classLabel.numberOfLines = self.separatorView.isHidden ? 0: 1
    }
}

class EffectResultTypeCell: EffectClassifiedCell {
    var resultType: SpectreResultType? {
        didSet {
            if let resultType = self.resultType {
                self.name = resultType.abbreviation

                if resultType.in( class: .template ) {
                    self.class = "Scheme"
                }
                else if resultType.in( class: .stateful ) {
                    self.class = "Saved"
                }
                else if resultType.in( class: .derive ) {
                    self.class = "Derive"
                }
                else {
                    self.class = nil
                }
            }
        }
    }
}
