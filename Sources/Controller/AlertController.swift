// =============================================================================
// Created by Maarten Billemont on 2018-09-22.
// Copyright (c) 2018 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import UIKit

#if TARGET_APP
extension AlertController {
    static func showChange(to site: Site, in viewController: UIViewController, by operation: () throws -> Void) rethrows {
        let oldSite = site.copy()
        try operation()

        if let oldPassword = oldSite.result( keyPurpose: .authentication ),
           let newPassword = site.result( keyPurpose: .authentication ) {
            oldPassword.token.and( newPassword.token ).success {
                if $0.0 != $0.1 {
                    self.forSite( site, in: viewController, changedFrom: oldSite )
                }
                else if let oldLogin = oldSite.result( keyPurpose: .identification ),
                        let newLogin = site.result( keyPurpose: .identification ) {
                    oldLogin.token.and( newLogin.token ).success {
                        if $0.0 != $0.1 {
                            self.forSite( site, in: viewController, changedFrom: oldSite )
                        }
                        else if let oldAnswer = oldSite.result( keyPurpose: .recovery ),
                                let newAnswer = site.result( keyPurpose: .recovery ) {
                            oldAnswer.token.and( newAnswer.token ).success {
                                if $0.0 != $0.1 {
                                    self.forSite( site, in: viewController, changedFrom: oldSite )
                                }
                            }.failure {
                                mperror( title: "Couldn't show site change", error: $0 )
                            }
                        }
                    }.failure {
                        mperror( title: "Couldn't show site change", error: $0 )
                    }
                }
            }.failure {
                mperror( title: "Couldn't show site change", error: $0 )
            }
        }
    }

    private static func forSite(_ site: Site, in viewController: UIViewController, changedFrom oldSite: Site) {
        AlertController( title: "Site Changed", message: site.siteName, details:
        """
        You've made changes to \(site.siteName).

        You should update the site's account to reflect these changes. We can help!
        """, content: EffectButton( title: "Help Me Update" ) { _ in
            viewController.present( DialogSiteChangedViewController( old: oldSite, new: site ), animated: true )
        } )
            .show( in: viewController.view )
    }
}
#endif

class AlertController {
    // The view owns the AlertController instead of the other way around since the controller's lifetime depends on the alert presence in the view.
    private weak var view: UIView?

    private lazy var titleLabel    = UILabel()
    private lazy var messageLabel  = UILabel()
    private lazy var expandChevron = UILabel()
    private lazy var detailLabel   = UILabel()

    private lazy var appearanceConfiguration = LayoutConfiguration( view: self.view ) { active, inactive in
        active.constrain { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor, constant: 4 ) }
        inactive.constrain { $1.topAnchor.constraint( equalTo: $0.bottomAnchor ) }
    }
    private lazy var activationConfiguration = LayoutConfiguration( view: self.view ).didSet { [unowned self] _, isActive in
        self.titleLabel => \.font => (isActive ? Theme.current.font.headline : Theme.current.font.headline)
        self.messageLabel => \.font => (isActive ? Theme.current.font.subheadline : Theme.current.font.subheadline)
        self.expandChevron.isHidden = isActive || self.detailLabel.text?.isEmpty ?? true
        self.detailLabel.isHidden = !isActive
    }

    // MARK: - Life

    private lazy var title   = self.titleFactory()
    private lazy var message = self.messageFactory()
    private lazy var details = self.detailsFactory()
    private lazy var content = self.contentFactory()
    private let titleFactory:   () -> String?
    private let messageFactory: () -> String?
    private let detailsFactory: () -> String?
    private let contentFactory: () -> UIView?
    private let level:          SpectreLogLevel

    init(title: @escaping @autoclosure () -> String?, message: @escaping @autoclosure () -> String? = nil,
         details: @escaping @autoclosure () -> String? = nil, content: @escaping @autoclosure () -> UIView? = nil,
         level: SpectreLogLevel = .info) {
        self.titleFactory = title
        self.messageFactory = message
        self.detailsFactory = details
        self.contentFactory = content
        self.level = level
        LeakRegistry.shared.register( self )
    }

    // MARK: - Interface

    @discardableResult
    public func show(in host: @escaping @autoclosure () -> UIView? = nil, dismissAutomatically: Bool = true,
                     file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle) -> Self {
        if let details = self.details {
            log( file: file, line: line, function: function, dso: dso, level: self.level, "%@: %@ [>PII]", [ self.title, self.message ] )
            pii( file: file, line: line, function: function, dso: dso, "> %@", details )
        }
        else {
            log( file: file, line: line, function: function, dso: dso, level: self.level, "%@: %@", [ self.title, self.message ] )
        }

        // TODO: Stack multiple alerts
        DispatchQueue.main.perform {
            let host   = host()
            var window = host?.window ?? host as? UIWindow
            #if TARGET_APP
            window = window ?? UIApplication.shared.windows.first
            #endif
            guard let window = window
            else {
                wrn( "No view to present alert: %@", self.title )
                return
            }

            let view = self.loadView()
            window.addSubview( view )
            self.view = view

            LayoutConfiguration( view: view )
                .constrain { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor, constant: -2 ) }
                .constrain { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor, constant: 2 ) }
                .activate()
            self.appearanceConfiguration.deactivate()
            self.activationConfiguration.deactivate()
            UIView.animate( withDuration: .long) { self.appearanceConfiguration.activate() } completion: { _ in
                if dismissAutomatically {
                    self.dismissTask.request()
                }
            }
        }

        return self
    }

    private lazy var dismissTask = DispatchTask( named: "Dismiss: \(self.title ?? "-")",
                                                 queue: .main, deadline: .now() + .seconds( 5 ) ) { [weak self] in
        guard let self = self, let view = self.view, view.superview != nil
        else { return }

        UIView.animate( withDuration: .long) { self.appearanceConfiguration.deactivate() } completion: { _ in
            view.removeFromSuperview()
        }
    }

    public func dismiss() {
        self.dismissTask.request( now: true )
    }

    public func activate() {
        self.dismissTask.cancel()

        DispatchQueue.main.perform {
            UIView.animate( withDuration: .long ) { self.activationConfiguration.activate() }
        }
    }

    // MARK: - Private

    private func loadView() -> UIView {
        let content = self.contentFactory()
        if let spinner = content as? UIActivityIndicatorView {
            spinner.startAnimating()
        }

        let contentStack = UIStackView( arrangedSubviews: [
            self.expandChevron, self.titleLabel, self.messageLabel, content, self.detailLabel,
        ].compactMap { $0 } )
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.axis = .vertical
        contentStack.alignment = .center
        contentStack.spacing = 8

        self.titleLabel.text = self.title
        self.titleLabel => \.textColor => Theme.current.color.body
        self.titleLabel.textAlignment = .center
        self.titleLabel.numberOfLines = 0

        self.messageLabel.text = self.message
        self.messageLabel => \.textColor => Theme.current.color.secondary
        self.messageLabel.textAlignment = .center
        self.messageLabel.numberOfLines = 0

        self.expandChevron.attributedText = NSAttributedString.icon( "caret-up" )
        self.expandChevron => \.textColor => Theme.current.color.body
        self.expandChevron.textAlignment = .center
        self.expandChevron.alignmentRectOutsets.top = -4

        self.detailLabel.text = self.details
        self.detailLabel => \.textColor => Theme.current.color.secondary
        self.detailLabel.textAlignment = .center
        self.detailLabel.numberOfLines = 0
        self.detailLabel => \.font => Theme.current.font.footnote

        let dismissRecognizer = UISwipeGestureRecognizer { _ in self.dismiss() }
        dismissRecognizer.direction = .down
        let activateRecognizer = UISwipeGestureRecognizer { _ in self.activate() }
        activateRecognizer.direction = .up

        let view = EffectView( content: contentStack )
        view.addGestureRecognizer( dismissRecognizer )
        view.addGestureRecognizer( activateRecognizer )
        view.addGestureRecognizer( UITapGestureRecognizer { _ in
            if !self.activationConfiguration.isActive && self.details?.nonEmpty != nil {
                self.activate()
            }
            else {
                self.dismiss()
            }
        } )

        return view
    }
}

public func mperror(title: String, message: CustomStringConvertible? = nil,
                    details: CustomStringConvertible? = nil, error: Error? = nil, in view: UIView? = nil,
                    file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle) {
    let error   = error?.details
    let message = message?.description ?? error?.description
    let details = [ details?.description, error?.failure != message ? error?.failure : nil, error?.suggestion,
                    error?.underlying.joined( separator: "\n" ), ]
        .compactMap( { $0 } ).joined( separator: "\n" )

    AlertController( title: title, message: message, details: details, level: .error )
        .show( in: view, file: file, line: line, function: function, dso: dso )
}
