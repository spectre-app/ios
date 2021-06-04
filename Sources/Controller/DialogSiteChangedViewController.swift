//
// Created by Maarten Billemont on 2019-07-05.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class DialogSiteChangedViewController: DialogViewController {

    private let oldSite: Site
    private let newSite: Site

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(old oldSite: Site, new newSite: Site) {
        self.oldSite = oldSite
        self.newSite = newSite

        super.init()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.closeButton.image = .icon( "" )
        self.backgroundView.image = self.newSite.preview.image
        self.backgroundView.imageColor = self.newSite.preview.color

        self.title = "Update Your Site"
        self.message =
                """
                Let's get \(self.oldSite.siteName) updated!

                Highlighted items have changed.
                Log into your site and update your account with the new values.
                """
    }

    override func populate(stackView: UIStackView) {
        super.populate( stackView: stackView )

        stackView.addArrangedSubview( MarginView( space: CGSize( width: 40, height: 40 ) ) )

        let oldSiteTitle = UILabel()
        oldSiteTitle => \.font => Theme.current.font.headline
        oldSiteTitle => \.textColor => Theme.current.color.body
        oldSiteTitle.textAlignment = .center
        oldSiteTitle.text = "Before"
        let newSiteTitle = UILabel()
        newSiteTitle => \.font => Theme.current.font.headline
        newSiteTitle => \.textColor => Theme.current.color.body
        newSiteTitle.textAlignment = .center
        newSiteTitle.text = "After"
        stackView.addArrangedSubview( UIStackView( arrangedSubviews: [ oldSiteTitle, newSiteTitle ], distribution: .fillEqually ) )

        let passwordTitle = UILabel()
        passwordTitle => \.font => Theme.current.font.subheadline
        passwordTitle => \.textColor => Theme.current.color.body
        passwordTitle.textAlignment = .center
        passwordTitle.text = "Password"
        stackView.addArrangedSubview( passwordTitle )

        let oldPassword = self.oldSite.result( keyPurpose: .authentication )
        let newPassword = self.newSite.result( keyPurpose: .authentication )
        let oldPasswordButton = EffectButton { [unowned self] in oldPassword.copy( fromView: self.view, trackingFrom: "site>changed" ) }
        let newPasswordButton = EffectButton { [unowned self] in newPassword.copy( fromView: self.view, trackingFrom: "site>changed" ) }
        oldPassword.token.then( on: .main ) { oldPasswordButton.title = try? $0.get() }
        newPassword.token.then( on: .main ) { newPasswordButton.title = try? $0.get() }
        oldPassword.token.and( newPassword.token ).success( on: .main ) {
            newPasswordButton.backgroundColor = $0.0 != $0.1 ? Theme.current.color.selection.get(): nil
        }
        stackView.addArrangedSubview( UIStackView( arrangedSubviews: [ oldPasswordButton, newPasswordButton ],
                                                   distribution: .fillEqually, spacing: 8 ) )

        let loginTitle = UILabel()
        loginTitle => \.font => Theme.current.font.subheadline
        loginTitle => \.textColor => Theme.current.color.body
        loginTitle.textAlignment = .center
        loginTitle.text = "Login Name"
        stackView.addArrangedSubview( loginTitle )

        let oldLogin = self.oldSite.result( keyPurpose: .identification )
        let newLogin = self.newSite.result( keyPurpose: .identification )
        let oldLoginButton = EffectButton { [unowned self] in oldLogin.copy( fromView: self.view, trackingFrom: "site>changed" ) }
        let newLoginButton = EffectButton { [unowned self] in newLogin.copy( fromView: self.view, trackingFrom: "site>changed" ) }
        oldLogin.token.then( on: .main ) { oldLoginButton.title = try? $0.get() }
        newLogin.token.then( on: .main ) { newLoginButton.title = try? $0.get() }
        oldLogin.token.and( newLogin.token ).success( on: .main ) {
            newLoginButton.backgroundColor = $0.0 != $0.1 ? Theme.current.color.selection.get(): nil
        }
        stackView.addArrangedSubview( UIStackView( arrangedSubviews: [ oldLoginButton, newLoginButton ],
                                                   distribution: .fillEqually, spacing: 8 ) )

        let answersTitle = UILabel()
        answersTitle => \.font => Theme.current.font.subheadline
        answersTitle => \.textColor => Theme.current.color.body
        answersTitle.textAlignment = .center
        answersTitle.text = "Security Answers"
        stackView.addArrangedSubview( answersTitle )

        let oldAnswer = self.oldSite.result( keyPurpose: .recovery )
        let newAnswer = self.newSite.result( keyPurpose: .recovery )
        let oldAnswerButton = EffectButton( title: "(generic)" ) { [unowned self] in
            oldAnswer.copy( fromView: self.view, trackingFrom: "site>changed" )
        }
        let newAnswerButton = EffectButton( title: "(generic)" ) { [unowned self] in
            newAnswer.copy( fromView: self.view, trackingFrom: "site>changed" )
        }
        oldAnswer.token.and( newAnswer.token ).success( on: .main ) {
            newAnswerButton.backgroundColor = $0.0 != $0.1 ? Theme.current.color.selection.get(): nil
        }
        stackView.addArrangedSubview( UIStackView( arrangedSubviews: [ oldAnswerButton, newAnswerButton ],
                                                   distribution: .fillEqually, spacing: 8 ) )

        for q in 0..<max( self.oldSite.questions.count, self.newSite.questions.count ) {
            let oldQuestion = q < self.oldSite.questions.count ? self.oldSite.questions[q]: nil
            let newQuestion = q < self.newSite.questions.count ? self.newSite.questions[q]: nil
            let oldAnswer   = oldQuestion?.result( keyPurpose: .recovery )
            let newAnswer   = newQuestion?.result( keyPurpose: .recovery )
            let oldAnswerButton = EffectButton( title: oldQuestion?.keyword ) {
                oldAnswer?.copy( fromView: self.view, trackingFrom: "site>changed" )
            }
            let newAnswerButton = EffectButton( title: newQuestion?.keyword ) {
                newAnswer?.copy( fromView: self.view, trackingFrom: "site>changed" )
            }
            oldAnswerButton.alpha = oldQuestion == nil ? .off: .on
            newAnswerButton.alpha = newQuestion == nil ? .off: .on
            if let oldToken = oldAnswer?.token, let newToken = newAnswer?.token {
                oldToken.and( newToken ).success {
                    newAnswerButton.backgroundColor = $0.0 != $0.1 ? Theme.current.color.selection.get(): nil
                }
            }
            stackView.addArrangedSubview( UIStackView( arrangedSubviews: [ oldAnswerButton, newAnswerButton ],
                                                       distribution: .fillEqually, spacing: 8 ) )
        }
    }
}
