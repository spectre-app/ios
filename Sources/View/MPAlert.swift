//
// Created by Maarten Billemont on 2018-09-22.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class MPAlert {
    private lazy var view          = self.loadView()
    private lazy var titleLabel    = UILabel()
    private lazy var messageLabel  = UILabel()
    private lazy var expandChevron = UILabel()
    private lazy var detailLabel   = UILabel()

    private lazy var appearanceConfiguration = LayoutConfiguration( view: self.view ) { active, inactive in
        active.constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor, constant: -4 ) }
        inactive.constrainTo { $1.bottomAnchor.constraint( equalTo: $0.topAnchor ) }
    }
    private lazy var activationConfiguration = LayoutConfiguration( view: self.view ) { (active, inactive) in
        active.apply( LayoutConfiguration( view: self.titleLabel ).set( appConfig.theme.font.title1.get(), forKey: "font" ) )
        active.apply( LayoutConfiguration( view: self.messageLabel ).set( appConfig.theme.font.title2.get(), forKey: "font" ) )
        active.apply( LayoutConfiguration( view: self.expandChevron ).set( true, forKey: "hidden" ) )
        active.apply( LayoutConfiguration( view: self.detailLabel ).set( false, forKey: "hidden" ) )
        inactive.apply( LayoutConfiguration( view: self.titleLabel ).set( appConfig.theme.font.headline.get(), forKey: "font" ) )
        inactive.apply( LayoutConfiguration( view: self.messageLabel ).set( appConfig.theme.font.subheadline.get(), forKey: "font" ) )
        inactive.apply( LayoutConfiguration( view: self.expandChevron ).set( self.detailLabel.text?.isEmpty ?? true, forKey: "hidden" ) )
        inactive.apply( LayoutConfiguration( view: self.detailLabel ).set( true, forKey: "hidden" ) )
    }
    private lazy var automaticDismissalTask = DispatchTask( queue: DispatchQueue.main, qos: .utility, deadline: .now() + .seconds( 3 ) ) {
        self.dismiss()
    }

    // MARK: --- Life ---

    private lazy var title   = self.titleFactory()
    private lazy var message = self.messageFactory()
    private lazy var details = self.detailsFactory()
    private lazy var content = self.contentFactory()
    private let titleFactory:   () -> String?
    private let messageFactory: () -> String?
    private let detailsFactory: () -> String?
    private let contentFactory: () -> (UIView?)
    private let level:          LogLevel

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(title: @escaping @autoclosure () -> String?, message: @escaping @autoclosure () -> String? = nil,
         details: @escaping @autoclosure () -> String? = nil, content: @escaping @autoclosure () -> (UIView?) = nil,
         level: LogLevel = .info) {
        self.titleFactory = title
        self.messageFactory = message
        self.detailsFactory = details
        self.contentFactory = content
        self.level = level
    }

    // MARK: --- Interface ---

    @discardableResult
    public func show(in view: UIView? = nil, dismissAutomatically: Bool = true,
                     file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle) -> Self {
        log( file: file, line: line, function: function, dso: dso, level: self.level, "[ %@ ]", [ self.title ] )
        trc( file: file, line: line, function: function, dso: dso, "> %@: %@", self.message, self.details )

        // TODO: Stack multiple alerts
        DispatchQueue.main.perform {
            if let root = view as? UIWindow ?? view?.window ?? UIApplication.shared.keyWindow {
                root.addSubview( self.view )

                LayoutConfiguration( view: self.view )
                        .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor, constant: -2 ) }
                        .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor, constant: 2 ) }
                        .activate()

                self.appearanceConfiguration.deactivate()
                self.activationConfiguration.deactivate()
                UIView.animate( withDuration: 0.618, animations: { self.appearanceConfiguration.activate() }, completion: { finished in
                    if dismissAutomatically {
                        self.automaticDismissalTask.request()
                    }
                } )
            }
        }

        return self
    }

    public func dismiss() {
        self.automaticDismissalTask.cancel()

        DispatchQueue.main.perform {
            UIView.animate( withDuration: 0.618, animations: { self.appearanceConfiguration.deactivate() }, completion: { finished in
                self.view.removeFromSuperview()
            } )
        }
    }

    public func activate() {
        self.automaticDismissalTask.cancel()

        DispatchQueue.main.perform {
            UIView.animate( withDuration: 0.618 ) { self.activationConfiguration.activate() }
        }
    }

    // MARK: --- Private ---

    private func loadView() -> UIView {
        let content = self.contentFactory()
        if let spinner = content as? UIActivityIndicatorView {
            spinner.startAnimating()
        }

        let contentStack = UIStackView( arrangedSubviews: [
            self.titleLabel, self.messageLabel, content, self.expandChevron, self.detailLabel
        ].compactMap { $0 } )
        contentStack.axis = .vertical
        contentStack.alignment = .center
        contentStack.spacing = 8

        let view = MPEffectView( content: contentStack, dark: true )
        if #available( iOS 11.0, * ) {
            view.insetsLayoutMarginsFromSafeArea = true
        }

        self.titleLabel.text = self.title
        self.titleLabel.textColor = appConfig.theme.color.body.get()
        self.titleLabel.textAlignment = .center
        self.titleLabel.numberOfLines = 0

        self.messageLabel.text = self.message
        self.messageLabel.textColor = appConfig.theme.color.secondary.get()
        self.messageLabel.textAlignment = .center
        self.messageLabel.numberOfLines = 0

        self.expandChevron.text = "▾"
        self.expandChevron.textColor = appConfig.theme.color.body.get()
        self.expandChevron.textAlignment = .center
        self.expandChevron.font = appConfig.theme.font.callout.get()
        self.expandChevron.alignmentRectOutsets = UIEdgeInsets( top: 0, left: 0, bottom: -8, right: 0 )

        self.detailLabel.text = self.details
        self.detailLabel.textColor = appConfig.theme.color.body.get()
        self.detailLabel.textAlignment = .center
        self.detailLabel.numberOfLines = 0
        self.detailLabel.font = appConfig.theme.font.footnote.get()

        let dismissRecognizer = UISwipeGestureRecognizer( target: self, action: #selector( self.didDismissSwipe ) )
        dismissRecognizer.direction = .up
        let activateRecognizer = UISwipeGestureRecognizer( target: self, action: #selector( self.didActivateSwipe ) )
        activateRecognizer.direction = .down
        view.addGestureRecognizer( dismissRecognizer )
        view.addGestureRecognizer( activateRecognizer )
        view.addGestureRecognizer( UITapGestureRecognizer( target: self, action: #selector( self.didTap ) ) )

        return view
    }

    @objc
    private func didTap(_ recognizer: UITapGestureRecognizer) {
        self.activate()
    }

    @objc
    private func didDismissSwipe(_ recognizer: UISwipeGestureRecognizer) {
        self.dismiss()
    }

    @objc
    private func didActivateSwipe(_ recognizer: UISwipeGestureRecognizer) {
        self.activate()
    }
}

public func mperror(title: String, message: CustomStringConvertible? = nil, details: CustomStringConvertible? = nil, error: Error? = nil,
                    file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle) {
    var errorDetails = details?.description
    if let error = error {
        if let errorDetails_ = errorDetails {
            errorDetails = "\(errorDetails_)\n\n\(error.localizedDescription)"
        }
        else {
            errorDetails = "\(error.localizedDescription)"
        }
    }

    MPAlert( title: title, message: message?.description, details: errorDetails, level: .error )
            .show( file: file, line: line, function: function, dso: dso )
}
