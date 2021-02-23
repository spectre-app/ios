//
// Created by Maarten Billemont on 2018-09-22.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class AlertController {
    private lazy var view          = self.loadView()
    private lazy var titleLabel    = UILabel()
    private lazy var messageLabel  = UILabel()
    private lazy var expandChevron = UILabel()
    private lazy var detailLabel   = UILabel()

    private lazy var appearanceConfiguration = LayoutConfiguration( view: self.view ) { active, inactive in
        active.constrain { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor, constant: 4 ) }
        inactive.constrain { $1.topAnchor.constraint( equalTo: $0.bottomAnchor ) }
    }
    private lazy var activationConfiguration = LayoutConfiguration( view: self.view )
            .apply( LayoutConfiguration( view: self.titleLabel ).didSet {
                $0 => \.font => ($1 ? Theme.current.font.headline: Theme.current.font.headline)
            } )
            .apply( LayoutConfiguration( view: self.messageLabel ).didSet {
                $0 => \.font => ($1 ? Theme.current.font.subheadline: Theme.current.font.subheadline)
            } )
            .apply( LayoutConfiguration( view: self.expandChevron ).didSet {
                $0.isHidden = $1 || self.detailLabel.text?.isEmpty ?? true
            } )
            .apply( LayoutConfiguration( view: self.detailLabel ).didSet {
                $0.isHidden = !$1
            } )
    private lazy var dismissTask = DispatchTask( named: "Dismiss Alert: \(self.title ?? "-")", queue: .main,
                                                 deadline: .now() + .seconds( 3 ), execute: { self.dismiss() } )

    // MARK: --- Life ---

    private lazy var title   = self.titleFactory()
    private lazy var message = self.messageFactory()
    private lazy var details = self.detailsFactory()
    private lazy var content = self.contentFactory()
    private let titleFactory:   () -> String?
    private let messageFactory: () -> String?
    private let detailsFactory: () -> String?
    private let contentFactory: () -> UIView?
    private let level:          SpectreLogLevel

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(title: @escaping @autoclosure () -> String?, message: @escaping @autoclosure () -> String? = nil,
         details: @escaping @autoclosure () -> String? = nil, content: @escaping @autoclosure () -> UIView? = nil,
         level: SpectreLogLevel = .info) {
        self.titleFactory = title
        self.messageFactory = message
        self.detailsFactory = details
        self.contentFactory = content
        self.level = level
    }

    // MARK: --- Interface ---

    @discardableResult
    public func show(in view: @escaping @autoclosure () -> UIView? = nil, dismissAutomatically: Bool = true,
                     file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle) -> Self {
        log( file: file, line: line, function: function, dso: dso, level: self.level, "[ %@ ]", [ self.title ] )
        pii( file: file, line: line, function: function, dso: dso, "> %@: %@", self.message, self.details )

        // TODO: Stack multiple alerts
        DispatchQueue.main.perform {
            let view   = view()
            var window = view?.window ?? view as? UIWindow
            #if TARGET_APP
            window = window ?? UIApplication.shared.keyWindow
            #endif
            if let window = window {
                window.addSubview( self.view )
            }
            else {
                wrn( "No view to present alert: %@", self.title )
                return
            }

            UIView.performWithoutAnimation {
                LayoutConfiguration( view: self.view )
                        .constrain { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor, constant: -2 ) }
                        .constrain { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor, constant: 2 ) }
                        .activate()

                self.appearanceConfiguration.deactivate()
                self.activationConfiguration.deactivate()
            }
            UIView.animate( withDuration: .long, animations: { self.appearanceConfiguration.activate() }, completion: { finished in
                if dismissAutomatically {
                    self.dismissTask.request()
                }
            } )
        }

        return self
    }

    public func dismiss() {
        self.dismissTask.cancel()

        DispatchQueue.main.perform {
            guard self.view.superview != nil
            else { return }

            UIView.animate( withDuration: .long, animations: { self.appearanceConfiguration.deactivate() }, completion: { finished in
                self.view.removeFromSuperview()
            } )
        }
    }

    public func activate() {
        self.dismissTask.cancel()

        DispatchQueue.main.perform {
            UIView.animate( withDuration: .long ) { self.activationConfiguration.activate() }
        }
    }

    // MARK: --- Private ---

    private func loadView() -> UIView {
        let content = self.contentFactory()
        if let spinner = content as? UIActivityIndicatorView {
            spinner.startAnimating()
        }

        let contentStack = UIStackView( arrangedSubviews: [
            self.expandChevron, self.titleLabel, self.messageLabel, content, self.detailLabel
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

        self.expandChevron.attributedText = NSAttributedString.icon( "" )
        self.expandChevron => \.textColor => Theme.current.color.body
        self.expandChevron.textAlignment = .center
        self.expandChevron.alignmentRectOutsets.top = -4

        self.detailLabel.text = self.details
        self.detailLabel => \.textColor => Theme.current.color.secondary
        self.detailLabel.textAlignment = .center
        self.detailLabel.numberOfLines = 0
        self.detailLabel => \.font => Theme.current.font.footnote

        let dismissRecognizer = UISwipeGestureRecognizer( target: self, action: #selector( self.didDismissSwipe ) )
        dismissRecognizer.direction = .down
        let activateRecognizer = UISwipeGestureRecognizer( target: self, action: #selector( self.didActivateSwipe ) )
        activateRecognizer.direction = .up

        let view = EffectView( content: contentStack )
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

public func mperror(title: String, message: CustomStringConvertible? = nil, details: CustomStringConvertible? = nil, error: Error? = nil, in view: UIView? = nil,
                    file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle) {
    let message = message?.description ?? error?.localizedDescription
    let details = [ details?.description, message == error?.localizedDescription ? nil: error?.localizedDescription,
                    (error as NSError?)?.localizedFailureReason,
                    (error as NSError?)?.localizedRecoverySuggestion,
                    ((error as NSError?)?.userInfo[NSUnderlyingErrorKey] as? Error)?.localizedDescription ]
            .compactMap( { $0 } ).joined( separator: "\n\n" )

    AlertController( title: title, message: message?.description, details: details, level: .error )
            .show( in: view, file: file, line: line, function: function, dso: dso )
}
