//
// Created by Maarten Billemont on 2021-11-07.
// Copyright (c) 2021 Lyndir. All rights reserved.
//

import Foundation
import SafariServices
import StoreKit

class FeedbackView: BaseView, Observed, Updatable, AppConfigObserver {
    let observers = Observers<FeedbackObserver>()

    let promptLabel  = UILabel()
    let starButtons  = UIStackView()
    let commentLabel = UILabel()
    let commentView  = UITextView()
    let contactLabel = UILabel()
    let contactField = UITextField()
    lazy var submittedButton = EffectButton( image: .icon( "stars" ), background: false ) { [unowned self] in
        self.viewController.flatMap { self.show( in: $0 ) }
    }
    lazy var submitButton = EffectButton( title: "Submit" ) { [unowned self] in
        self.submit()
    }

    weak var viewController: UIViewController?
    var shown     = false {
        didSet {
            if oldValue != self.shown {
                self.updateTask.request()
            }
        }
    }
    var submitted = false {
        didSet {
            if oldValue != self.submitted {
                self.updateTask.request()
            }
        }
    }
    var expanded  = false {
        didSet {
            if oldValue != self.expanded {
                self.updateTask.request()
            }
        }
    }

    override func loadView() {
        AppConfig.shared.observers.register( observer: self )

        // - View
        self.translatesAutoresizingMaskIntoConstraints = false

        self.promptLabel => \.textColor => Theme.current.color.secondary
        self.promptLabel => \.font => Theme.current.font.caption2
        self.promptLabel.textAlignment = .center
        self.promptLabel.text = "How are we doing?"

        self.commentLabel => \.textColor => Theme.current.color.secondary
        self.commentLabel => \.font => Theme.current.font.caption2
        self.commentLabel.textAlignment = .center
        self.commentLabel.text = "Leave us a comment?"
        self.commentView => \.font => Theme.current.font.mono
        self.commentView => \.textColor => Theme.current.color.body
        self.commentView => \.backgroundColor => Theme.current.color.selection
        self.commentView.textAlignment = .center
        self.commentView.layer.cornerRadius = 8

        self.contactLabel => \.textColor => Theme.current.color.secondary
        self.contactLabel => \.font => Theme.current.font.caption2
        self.contactLabel.textAlignment = .center
        self.contactLabel.text = "Can we get back to you?"
        self.contactField.placeholder = "E-mail address"
        self.contactField => \.font => Theme.current.font.body
        self.contactField => \.textColor => Theme.current.color.body
        self.contactField.textAlignment = .center
        self.contactField.autocapitalizationType = .none
        self.contactField.autocorrectionType = .no
        self.contactField.keyboardType = .emailAddress

        self.starButtons.spacing = 8
        self.starButtons.addArrangedSubview( EffectButton( image: .icon( "star", style: .regular ) ) { [unowned self] in self.rate( 1 ) } )
        self.starButtons.addArrangedSubview( EffectButton( image: .icon( "star", style: .regular ) ) { [unowned self] in self.rate( 2 ) } )
        self.starButtons.addArrangedSubview( EffectButton( image: .icon( "star", style: .regular ) ) { [unowned self] in self.rate( 3 ) } )
        self.starButtons.addArrangedSubview( EffectButton( image: .icon( "star", style: .regular ) ) { [unowned self] in self.rate( 4 ) } )
        self.starButtons.addArrangedSubview( EffectButton( image: .icon( "star", style: .regular ) ) { [unowned self] in self.rate( 5 ) } )

        // - Hierarchy
        self.addSubview( UIStackView( arrangedSubviews: [
            self.promptLabel, self.starButtons,
            self.commentLabel, self.commentView,
            self.contactLabel, self.contactField,
            self.submitButton, self.submittedButton
        ], axis: .vertical, spacing: 8 ) )

        // - Layout
        LayoutConfiguration( view: self.subviews.first )
            .constrain( as: .box ).activate()
        LayoutConfiguration( view: self.commentView )
            .constrain { $1.heightAnchor.constraint( equalToConstant: 88 ) }.activate()
    }

    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove( toSuperview: newSuperview )
        self.updateTask.request()
    }

    func show(in viewController: UIViewController) {
        self.viewController = viewController
        self.shown = true
        self.submitted = false
        self.expanded = false
    }

    // MARK: - Internal

    private func rate(_ rating: Int) {
        self.submitted = false
        self.expanded = true
        AppConfig.shared.rating = rating
    }

    private func submit() {
        self.commentView.resignFirstResponder()
        self.contactField.resignFirstResponder()

        self.expanded = false
        self.submitted = true

        Tracker.shared.feedback( AppConfig.shared.rating,
                                 comment: self.commentView.text.nonEmpty,
                                 contact: self.contactField.text?.nonEmpty )

        if AppConfig.shared.reviewed == nil, AppConfig.shared.rating == 5 {
            if let viewController = self.viewController, !self.commentView.text.isEmpty,
               let url = URL( string: "https://apps.apple.com/us/app/password-spectre/id1526402806?action=write-review" ) {
                let controller = UIAlertController( title: "Publish Review?", message:
                """
                Sharing your thoughts on the App Store helps us immeasurably.
                Would you like to write a short public review?
                """, preferredStyle: .actionSheet )
                controller.addAction( UIAlertAction( title: "Not now", style: .cancel ) )
                controller.addAction( UIAlertAction( title: "I will!", style: .default ) { _ in
                    UIApplication.shared.open( url )
                    AppConfig.shared.reviewed = Date()
                } )
                viewController.present( controller, animated: true )
            }
            else {
                (self.window?.windowScene).flatMap {
                    SKStoreReviewController.requestReview( in: $0 )
                    AppConfig.shared.reviewed = Date()
                }
            }
        }
    }

    lazy var updateTask: DispatchTask<Void> = DispatchTask.update( self, animated: true ) { [weak self] in
        guard let self = self
        else { return }

        let rating = AppConfig.shared.rating
        self.starButtons.arrangedSubviews.enumerated().forEach {
            ($0.element as? EffectButton)?.image = .icon( "star", style: $0.offset < rating ? .solid : .regular )
        }

        if rating <= 2 {
            self.commentLabel.text = "Sorry about that! What's going wrong?"
        }
        else if rating <= 3 {
            self.commentLabel.text = "What could we do better for you?"
        }
        else {
            self.commentLabel.text = "Thanks! Leave us a comment?"
        }

        self.promptLabel.isHidden = !self.shown || self.submitted
        self.starButtons.isHidden = !self.shown || self.submitted
        self.commentLabel.isHidden = !self.shown || self.submitted || !self.expanded
        self.commentView.isHidden = !self.shown || self.submitted || !self.expanded
        self.contactLabel.isHidden = !self.shown || self.submitted || !self.expanded
        self.contactField.isHidden = !self.shown || self.submitted || !self.expanded
        self.submitButton.isHidden = !self.shown || self.submitted || !self.expanded
        self.submittedButton.isHidden = !self.shown || !self.submitted

        if self.commentView.isHidden {
            self.commentView.resignFirstResponder()
        }
        if self.contactField.isHidden {
            self.contactField.resignFirstResponder()
        }

        self.observers.notify {
            $0.didUpdate( feedback: self, shown: self.shown, expanded: self.expanded, submitted: self.submitted )
        }

        self.window?.layoutIfNeeded()
    }

    // - AppConfigObserver

    func didChange(appConfig: AppConfig, at change: PartialKeyPath<AppConfig>) {
        if change == \AppConfig.rating {
            self.updateTask.request()
        }
    }
}

class FeedbackItem<M>: Item<M> {
    override func createItemView() -> FeedbackItemView {
        FeedbackItemView( withItem: self )
    }

    class FeedbackItemView: ItemView, FeedbackObserver {
        lazy var feedbackView = FeedbackView()

        override func createValueView() -> UIView? {
            self.feedbackView.observers.register( observer: self )
            return self.feedbackView
        }

        override func didLoad() {
            super.didLoad()

            (self.item?.viewController).flatMap {
                self.feedbackView.show( in: $0 )
            }
        }

        override func doUpdate() async {
            await super.doUpdate()

            try? await self.feedbackView.updateTask.requestNow()
        }

        // - FeedbackObserver

        func didUpdate(feedback: FeedbackView, shown: Bool, expanded: Bool, submitted: Bool) {
            self.isHidden = !shown
        }
    }
}

protocol FeedbackObserver {
    func didUpdate(feedback: FeedbackView, shown: Bool, expanded: Bool, submitted: Bool)
}
