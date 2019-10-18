//
// Created by Maarten Billemont on 2018-09-22.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPAlert {
    private var view: MPButton!
    private lazy var titleLabel    = UILabel()
    private lazy var messageLabel  = UILabel()
    private lazy var expandChevron = UILabel()
    private lazy var detailLabel   = UILabel()

    private lazy var appearanceConfiguration = LayoutConfiguration( view: self.view ) { active, inactive in
        active.constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor, constant: -4 ) }
        inactive.constrainTo { $1.bottomAnchor.constraint( equalTo: $0.topAnchor ) }
    }
    private lazy var activationConfiguration = LayoutConfiguration( view: self.view ) { (active, inactive) in
        active.apply( LayoutConfiguration( view: self.titleLabel ).set( MPTheme.global.font.title1.get(), forKey: "font" ) )
        active.apply( LayoutConfiguration( view: self.messageLabel ).set( MPTheme.global.font.title2.get(), forKey: "font" ) )
        active.apply( LayoutConfiguration( view: self.expandChevron ).set( true, forKey: "hidden" ) )
        active.apply( LayoutConfiguration( view: self.detailLabel ).set( false, forKey: "hidden" ) )
        inactive.apply( LayoutConfiguration( view: self.titleLabel ).set( MPTheme.global.font.headline.get(), forKey: "font" ) )
        inactive.apply( LayoutConfiguration( view: self.messageLabel ).set( MPTheme.global.font.subheadline.get(), forKey: "font" ) )
        inactive.apply( LayoutConfiguration( view: self.expandChevron ).set( self.detailLabel.text?.isEmpty ?? true, forKey: "hidden" ) )
        inactive.apply( LayoutConfiguration( view: self.detailLabel ).set( true, forKey: "hidden" ) )
    }
    private lazy var automaticDismissalTask = DispatchTask( queue: DispatchQueue.main, qos: .utility, deadline: .now() + .seconds( 3 ) ) {
        self.dismiss()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(title: String?, message: String? = nil, content: @escaping @autoclosure (() -> (UIView?)) = nil, details: String? = nil) {
        DispatchQueue.main.perform {
            let content = content()
            let contentStack = UIStackView( arrangedSubviews: [
                self.titleLabel, self.messageLabel, content, self.expandChevron, self.detailLabel
            ].compactMap { $0 } )
            self.view = MPButton( content: contentStack )

            // - View
            self.view.darkBackground = true
            if #available( iOS 11.0, * ) {
                self.view.insetsLayoutMarginsFromSafeArea = true
            }

            self.titleLabel.text = title
            self.titleLabel.textColor = MPTheme.global.color.body.get()
            self.titleLabel.textAlignment = .center
            self.titleLabel.numberOfLines = 0

            self.messageLabel.text = message
            self.messageLabel.textColor = MPTheme.global.color.secondary.get()
            self.messageLabel.textAlignment = .center
            self.messageLabel.numberOfLines = 0

            if let spinner = content as? UIActivityIndicatorView {
                spinner.startAnimating()
            }

            self.expandChevron.text = "▾"
            self.expandChevron.textColor = MPTheme.global.color.body.get()
            self.expandChevron.textAlignment = .center
            self.expandChevron.font = MPTheme.global.font.callout.get()
            self.expandChevron.setAlignmentRectInsets( UIEdgeInsets( top: 0, left: 0, bottom: 8, right: 0 ) )

            self.detailLabel.text = details
            self.detailLabel.textColor = MPTheme.global.color.body.get()
            self.detailLabel.textAlignment = .center
            self.detailLabel.numberOfLines = 0
            self.detailLabel.font = MPTheme.global.font.footnote.get()

            let dismissRecognizer = UISwipeGestureRecognizer( target: self, action: #selector( self.didDismissSwipe ) )
            dismissRecognizer.direction = .up
            let activateRecognizer = UISwipeGestureRecognizer( target: self, action: #selector( self.didActivateSwipe ) )
            activateRecognizer.direction = .down
            self.view.addGestureRecognizer( dismissRecognizer )
            self.view.addGestureRecognizer( activateRecognizer )
            self.view.addGestureRecognizer( UITapGestureRecognizer( target: self, action: #selector( self.didTap ) ) )

            contentStack.axis = .vertical
            contentStack.alignment = .center
            contentStack.spacing = 8
        }
    }

    @discardableResult
    public func show(in view: UIView? = nil, dismissAutomatically: Bool = true) -> Self {
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

    @objc
    func didTap(_ recognizer: UITapGestureRecognizer) {
        self.activate()
    }

    @objc
    func didDismissSwipe(_ recognizer: UISwipeGestureRecognizer) {
        self.dismiss()
    }

    @objc
    func didActivateSwipe(_ recognizer: UISwipeGestureRecognizer) {
        self.activate()
    }
}

func mperror(title: String, context: CustomStringConvertible? = nil, details: CustomStringConvertible? = nil, error: Error? = nil) {
    var errorDetails = details?.description
    if let error = error {
        if let errorDetails_ = errorDetails {
            errorDetails = "\(errorDetails_)\n\n\(error)"
        }
        else {
            errorDetails = "\(error)"
        }
    }

    var message = title
    if let context = context {
        message += " (\(context))"
    }
    if let errorDetails = errorDetails {
        message += ": \(errorDetails)"
    }
    err( message )

    DispatchQueue.main.perform {
        MPAlert( title: title, message: context?.description, details: errorDetails ).show()
    }
}