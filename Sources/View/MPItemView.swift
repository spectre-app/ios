//
// Created by Maarten Billemont on 2019-04-26.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class AnyItem: NSObject, Updatable {
    let title: String?

    private lazy var updateTask = DispatchTask( named: self.title, queue: .main, deadline: .now() + .milliseconds( 100 ),
                                                update: self, animated: true )

    init(title: String? = nil) {
        self.title = title
    }

    func setNeedsUpdate() {
        self.updateTask.request()
    }

    func update() {
        self.updateTask.cancel()
    }
}

class Item<M>: AnyItem {
    public weak var viewController: MPItemsViewController<M>? {
        didSet {
            ({ self.subitems.forEach { $0.viewController = self.viewController } }())
        }
    }
    public var model: M? {
        didSet {
            ({ self.subitems.forEach { $0.model = self.model } }())

            self.setNeedsUpdate()
        }
    }
    private var behaviours = [ Behaviour<M> ]()

    private let captionProvider: (M) -> CustomStringConvertible?
    private let subitems:        [Item<M>]
    private let subitemMode:     SubItemMode
    private (set) lazy var view = createItemView()

    var updatesPostponed: Bool {
        self.viewController?.updatesPostponed ?? true
    }

    init(title: String? = nil, subitems: [Item<M>] = [ Item<M> ](), as subitemMode: SubItemMode = .inline,
         caption captionProvider: @escaping (M) -> CustomStringConvertible? = { _ in nil }) {
        self.subitems = subitems
        self.subitemMode = subitemMode
        self.captionProvider = captionProvider

        super.init( title: title )
    }

    func createItemView() -> ItemView {
        ItemView( withItem: self )
    }

    @discardableResult
    func addBehaviour(_ behaviour: Behaviour<M>) -> Self {
        self.behaviours.append( behaviour )
        behaviour.didInstall( into: self )
        return self
    }

    // MARK: --- Updatable ---

    override func update() {
        super.update()

        self.view.update()
        self.behaviours.forEach { $0.didUpdate( item: self ) }
        self.subitems.forEach { $0.update() }
    }

    // MARK: --- Types ---

    enum SubItemMode {
        case inline, pager
    }

    class ItemView: UIView, Updatable {
        let titleLabel    = UILabel()
        let captionLabel  = UILabel()
        let contentView   = UIStackView()
        let subitemsStack = UIStackView()
        let subitemsPager = MPPagerView()

        private lazy var valueView = self.createValueView()
        private let item: Item<M>

        override var forLastBaselineLayout: UIView {
            self.titleLabel
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        init(withItem item: Item<M>) {
            self.item = item
            super.init( frame: .zero )

            // - View
            self.translatesAutoresizingMaskIntoConstraints = false

            self.contentView.axis = .vertical
            self.contentView.alignment = .center
            self.contentView.spacing = 8

            self.titleLabel.numberOfLines = 0
            self.titleLabel => \.textColor => Theme.current.color.body
            self.titleLabel.textAlignment = .center
            self.titleLabel => \.font => Theme.current.font.headline
            self.titleLabel.setContentHuggingPriority( .defaultHigh, for: .vertical )

            self.subitemsStack.axis = .horizontal
            self.subitemsStack.distribution = .fillEqually
            self.subitemsStack.alignment = .lastBaseline
            self.subitemsStack.spacing = 20
            self.subitemsStack.preservesSuperviewLayoutMargins = true
            self.subitemsStack.isLayoutMarginsRelativeArrangement = true
            self.subitemsStack.isHidden = true
            self.subitemsPager.isHidden = true

            self.captionLabel => \.textColor => Theme.current.color.secondary
            self.captionLabel.textAlignment = .center
            self.captionLabel => \.font => Theme.current.font.caption1
            self.captionLabel.numberOfLines = 0
            self.captionLabel.setContentHuggingPriority( .defaultHigh, for: .vertical )

            // - Hierarchy
            self.addSubview( self.contentView )
            self.contentView.addArrangedSubview( MPMarginView( for: self.titleLabel, margins: .horizontal() ) )
            if let valueView = self.valueView {
                self.contentView.addArrangedSubview( valueView )
            }
            self.contentView.addArrangedSubview( self.subitemsStack )
            self.contentView.addArrangedSubview( self.subitemsPager )
            self.contentView.addArrangedSubview( MPMarginView( for: self.captionLabel, margins: .horizontal() ) )

            // - Layout
            LayoutConfiguration( view: self.contentView )
                    .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                    .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                    .activate()

            LayoutConfiguration( view: self.subitemsStack )
                    .constrainTo { $1.widthAnchor.constraint( equalTo: $0.widthAnchor ).with( priority: .defaultHigh ) }
                    .constrainTo { $1.heightAnchor.constraint( equalToConstant: 0 ).with( priority: .fittingSizeLevel ) }
                    .activate()

            LayoutConfiguration( view: self.subitemsPager )
                    .constrainTo {
                        $1.widthAnchor.constraint( equalTo: $0.widthAnchor ).with( priority: .defaultLow + 1 )
                    }
                    .constrainTo { $1.heightAnchor.constraint( equalToConstant: 0 ).with( priority: .fittingSizeLevel ) }
                    .activate()
        }

        /** Create a custom view for rendering this item's value. */
        func createValueView() -> UIView? {
            nil
        }

        /** The view was loaded and added to the view hierarchy. */
        func didLoad() {
            if let valueView = self.valueView {
                valueView.superview?.readableContentGuide.widthAnchor.constraint( equalTo: valueView.widthAnchor )
                                                                     .with( priority: .defaultLow + 1 ).isActive = true
            }

            self.subitemsPager.pages = self.item.subitems.map { $0.view }
        }

        // MARK: --- Updatable ---

        func update() {
            let behaveHidden = self.item.behaviours.reduce( false ) { $0 || ($1.isHidden( item: self.item ) ?? $0) }
            let behaveEnabled = self.item.behaviours.reduce( true ) { $0 && ($1.isEnabled( item: self.item ) ?? $0) }

            self.isHidden = behaveHidden
            self.alpha = behaveEnabled ? .on: .short
            self.contentView.isUserInteractionEnabled = behaveEnabled
            self.tintAdjustmentMode = behaveEnabled ? .automatic: .dimmed

            self.titleLabel.text = self.item.title
            self.titleLabel.isHidden = self.item.title == nil

            self.captionLabel.text = self.item.model.flatMap { self.item.captionProvider( $0 )?.description }
            self.captionLabel.isHidden = self.captionLabel.text == nil

            switch self.item.subitemMode {
                case .inline:
                    for i in 0..<max( self.item.subitems.count, self.subitemsStack.arrangedSubviews.count ) {
                        let subitemView  = i < self.item.subitems.count ? self.item.subitems[i].view: nil
                        let arrangedView = i < self.subitemsStack.arrangedSubviews.count ? self.subitemsStack.arrangedSubviews[i]: nil

                        if arrangedView != subitemView {
                            arrangedView?.removeFromSuperview()

                            if let subitemView = subitemView {
                                self.subitemsStack.insertArrangedSubview( subitemView, at: i )
                            }
                        }
                    }
                    self.subitemsStack.isHidden = self.subitemsStack.arrangedSubviews.count == 0
                    self.subitemsPager.isHidden = true

                case .pager:
                    self.subitemsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
                    self.subitemsStack.isHidden = true
                    self.subitemsPager.isHidden = false
            }
        }
    }
}

class Behaviour<M> {
    private let hiddenProvider:  ((M) -> Bool)?
    private let enabledProvider: ((M) -> Bool)?
    private var items = [ WeakBox<Item<M>> ]()

    init(hidden hiddenProvider: ((M) -> Bool)? = nil, enabled enabledProvider: ((M) -> Bool)? = nil) {
        self.hiddenProvider = hiddenProvider
        self.enabledProvider = enabledProvider
    }

    func didInstall(into item: Item<M>) {
        self.didUpdate( item: item )
        self.items.append( WeakBox( item ) )
    }

    func didUpdate(item: Item<M>) {
    }

    func setNeedsUpdate() {
        self.items.forEach { $0.value?.setNeedsUpdate() }
    }

    func isHidden(item: Item<M>) -> Bool? {
        if let model = item.model, let hiddenProvider = self.hiddenProvider {
            return hiddenProvider( model )
        }

        return nil
    }

    func isEnabled(item: Item<M>) -> Bool? {
        if let model = item.model, let enabledProvider = self.enabledProvider {
            return enabledProvider( model )
        }

        return nil
    }
}

class TapBehaviour<M>: Behaviour<M> {
    var tapRecognizers = [ UIGestureRecognizer: Item<M> ]()
    var isEnabled = true {
        didSet {
            self.tapRecognizers.forEach {
                $0.key.isEnabled = self.isEnabled
                $0.value.view.contentView.isUserInteractionEnabled = !self.isEnabled
            }
        }
    }

    override func didInstall(into item: Item<M>) {
        super.didInstall( into: item )

        let tapRecognizer = UITapGestureRecognizer( target: self, action: #selector( didReceiveGesture ) )
        tapRecognizer.name = _describe( type( of: self ) )
        tapRecognizer.isEnabled = self.isEnabled
        self.tapRecognizers[tapRecognizer] = item
        item.view.addGestureRecognizer( tapRecognizer )
        item.view.contentView.isUserInteractionEnabled = !self.isEnabled
    }

    @objc func didReceiveGesture(_ recognizer: UIGestureRecognizer) {
        if let item = self.tapRecognizers[recognizer], recognizer.state == .ended {
            self.doTapped( item: item )
        }
    }

    func doTapped(item: Item<M>) {
    }
}

class BlockTapBehaviour<M>: TapBehaviour<M> {
    let enabled: (Item<M>) -> Bool
    let tapped:  (Item<M>) -> ()

    init(enabled: @escaping (Item<M>) -> Bool = { _ in true }, _ tapped: @escaping (Item<M>) -> ()) {
        self.enabled = enabled
        self.tapped = tapped

        super.init()
    }

    override func didUpdate(item: Item<M>) {
        super.didUpdate( item: item )

        self.isEnabled = self.enabled( item )
    }

    override func doTapped(item: Item<M>) {
        self.tapped( item )
    }
}

class ConditionalBehaviour<M>: Behaviour<M> {
    init(mode: Effect, condition: @escaping (M) -> Bool) {
        super.init( hidden: { model in
            switch mode {
                case .enables:
                    return false
                case .reveals:
                    return !condition( model )
                case .hides:
                    return condition( model )
            }
        }, enabled: { model in
            switch mode {
                case .enables:
                    return condition( model )
                case .reveals:
                    return true
                case .hides:
                    return true
            }
        } )
    }

    enum Effect {
        case enables
        case reveals
        case hides
    }
}

class PremiumConditionalBehaviour<M>: ConditionalBehaviour<M>, InAppFeatureObserver {

    init(mode: Effect) {
        super.init( mode: mode, condition: { _ in InAppFeature.premium.enabled() } )

        InAppFeature.observers.register( observer: self )
    }

    // MARK: --- InAppFeatureObserver ---

    func featureDidChange(_ feature: InAppFeature) {
        self.setNeedsUpdate()
    }
}

class RequiresDebug<M>: ConditionalBehaviour<M> {
    init(mode: Effect) {
        super.init( mode: mode, condition: { _ in appConfig.isDebug } )
    }
}

class SeparatorItem<M>: Item<M> {
    override func createItemView() -> ItemView {
        SeparatorItemView( withItem: self )
    }

    class SeparatorItemView: ItemView {
        let item: SeparatorItem
        let separatorView = UIView()

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item<M>) {
            self.item = item as! SeparatorItem
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.separatorView => \.backgroundColor => Theme.current.color.mute
            self.separatorView.heightAnchor.constraint( equalToConstant: 1 ).isActive = true
            return self.separatorView
        }
    }
}

class ValueItem<M, V>: Item<M> {
    let valueProvider: (M) -> V?
    var value: V? {
        self.model.flatMap { self.valueProvider( $0 ) }
    }

    init(title: String? = nil, subitems: [Item<M>] = [ Item<M> ](),
         value valueProvider: @escaping (M) -> V? = { _ in nil },
         caption: @escaping (M) -> CustomStringConvertible? = { _ in nil }) {
        self.valueProvider = valueProvider
        super.init( title: title, subitems: subitems, caption: caption )
    }
}

class LabelItem<M>: ValueItem<M, Any> {
    override func createItemView() -> LabelItemView {
        LabelItemView( withItem: self )
    }

    class LabelItemView: ItemView {
        let item: LabelItem
        let valueLabel = UILabel()

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item<M>) {
            self.item = item as! LabelItem
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.valueLabel => \.font => Theme.current.font.largeTitle
            self.valueLabel.textAlignment = .center
            self.valueLabel => \.textColor => Theme.current.color.body
            self.valueLabel => \.shadowColor => Theme.current.color.shadow
            self.valueLabel.shadowOffset = CGSize( width: 0, height: 1 )

            return self.valueLabel
        }

        override func update() {
            super.update()

            let value = self.item.value
            if let value = value as? NSAttributedString {
                self.valueLabel.attributedText = value
                self.valueLabel.isHidden = false
            }
            else if let value = value {
                self.valueLabel.text = String( describing: value )
                self.valueLabel.isHidden = false
            }
            else {
                self.valueLabel.text = nil
                self.valueLabel.attributedText = nil
                self.valueLabel.isHidden = true
            }
        }
    }
}

class ImageItem<M>: ValueItem<M, UIImage> {
    override func createItemView() -> ImageItemView {
        ImageItemView( withItem: self )
    }

    class ImageItemView: ItemView {
        let item: ImageItem
        let valueImage = UIImageView()

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item<M>) {
            self.item = item as! ImageItem
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.valueImage.setContentHuggingPriority( .defaultHigh, for: .horizontal )
            self.valueImage.setContentHuggingPriority( .defaultHigh, for: .vertical )
            return self.valueImage
        }

        override func update() {
            super.update()

            self.valueImage.image = self.item.value
            self.valueImage.isHidden = self.valueImage.image == nil
        }
    }
}

class ToggleItem<M>: ValueItem<M, (icon: UIImage?, selected: Bool, enabled: Bool)> {
    let identifier: String
    let update:     (M, Bool) -> Void

    init(identifier: String, title: String? = nil, subitems: [Item<M>] = [],
         value: @escaping (M) -> (icon: UIImage?, selected: Bool, enabled: Bool),
         update: @escaping (M, Bool) -> Void = { _, _ in },
         caption: @escaping (M) -> CustomStringConvertible? = { _ in nil }) {
        self.identifier = identifier
        self.update = update

        super.init( title: title, subitems: subitems, value: value, caption: caption )
    }

    override func createItemView() -> ToggleItemView {
        ToggleItemView( withItem: self )
    }

    class ToggleItemView: ItemView {
        let item: ToggleItem
        lazy var button = MPToggleButton( identifier: self.item.identifier )

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item<M>) {
            self.item = item as! ToggleItem
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.button.action( for: .primaryActionTriggered ) { [unowned self] in
                if let model = self.item.model {
                    self.item.update( model, self.button.isSelected )
                    self.item.setNeedsUpdate()
                }
            }
            return self.button
        }

        override func update() {
            super.update()

            let value = self.item.value
            self.button.image = value?.icon
            self.button.isEnabled = value?.enabled ?? false
            self.button.isSelected = value?.selected ?? false
        }
    }
}

class ButtonItem<M>: ValueItem<M, (label: String?, image: UIImage?)> {
    let identifier: String
    let action:     (ButtonItem<M>) -> Void

    init(identifier: String, title: String? = nil, subitems: [Item<M>] = [],
         value: @escaping (M) -> (label: String?, image: UIImage?),
         caption: @escaping (M) -> CustomStringConvertible? = { _ in nil },
         action: @escaping (ButtonItem<M>) -> Void = { _ in }) {
        self.identifier = identifier
        self.action = action

        super.init( title: title, subitems: subitems, value: value, caption: caption )
    }

    override func createItemView() -> ButtonItemView {
        ButtonItemView( withItem: self )
    }

    class ButtonItemView: ItemView {
        let item: ButtonItem

        lazy var button = MPButton( identifier: self.item.identifier ) { [unowned self] _, _ in
            self.item.action( self.item )
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item<M>) {
            self.item = item as! ButtonItem
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.button
        }

        override func update() {
            super.update()

            let value = self.item.value
            self.button.title = value?.label
            self.button.image = value?.image
        }
    }
}

class DateItem<M>: ValueItem<M, Date> {
    override func createItemView() -> DateItemView {
        DateItemView( withItem: self )
    }

    class DateItemView: ItemView {
        let item: DateItem
        let valueView = UIView()
        let dateView  = MPDateView()

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item<M>) {
            self.item = item as! DateItem
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.valueView.addSubview( self.dateView )

            LayoutConfiguration( view: self.dateView )
                    .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                    .constrainTo { $1.leadingAnchor.constraint( greaterThanOrEqualTo: $0.leadingAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( lessThanOrEqualTo: $0.trailingAnchor ) }
                    .constrainTo { $1.centerXAnchor.constraint( equalTo: $0.centerXAnchor ) }
                    .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                    .activate()

            return self.valueView
        }

        override func update() {
            super.update()

            self.dateView.date = self.item.value
        }
    }
}

class FieldItem<M>: ValueItem<M, String>, UITextFieldDelegate {
    let placeholder: String?
    let update:      ((M, String) -> Void)?

    init(title: String? = nil, placeholder: String?, subitems: [Item<M>] = [],
         value: @escaping (M) -> String? = { _ in nil },
         update: ((M, String) -> Void)? = nil,
         caption: @escaping (M) -> CustomStringConvertible? = { _ in nil }) {
        self.placeholder = placeholder
        self.update = update
        super.init( title: title, subitems: subitems, value: value, caption: caption )
    }

    override func createItemView() -> FieldItemView {
        FieldItemView( withItem: self )
    }

    // MARK: UITextFieldDelegate
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        self.update != nil
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing( false )
        return true
    }

    class FieldItemView: ItemView {
        let item: FieldItem
        let valueField = UITextField()

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item<M>) {
            self.item = item as! FieldItem
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.valueField.delegate = self.item
            self.valueField => \.textColor => Theme.current.color.body
            self.valueField.textAlignment = .center
            self.valueField.setContentHuggingPriority( .defaultLow + 100, for: .horizontal )
            self.valueField.action( for: .editingChanged ) { [unowned self] in
                if let model = self.item.model,
                   let text = self.valueField.text {
                    self.item.update?( model, text )
                }
            }
            return self.valueField
        }

        override func update() {
            super.update()

            self.valueField.placeholder = self.item.placeholder
            self.valueField.text = self.item.value
        }
    }
}

class AreaItem<M, V>: ValueItem<M, V>, UITextViewDelegate {
    let update: ((M, V) -> Void)?

    init(title: String? = nil, subitems: [Item<M>] = [],
         value: @escaping (M) -> V? = { _ in nil },
         update: ((M, V) -> Void)? = nil,
         caption: @escaping (M) -> CustomStringConvertible? = { _ in nil }) {
        self.update = update
        super.init( title: title, subitems: subitems, value: value, caption: caption )
    }

    override func createItemView() -> AreaItemView {
        AreaItemView( withItem: self )
    }

    // MARK: UITextViewDelegate

    func textViewDidChange(_ textView: UITextView) {
        if let model = self.model, let update = update {
            if let value = textView.text as? V {
                update( model, value )
            }
            else if let value = textView.attributedText as? V {
                update( model, value )
            }
        }
    }

    class AreaItemView: ItemView {
        let item: AreaItem
        let valueView = UITextView()

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item<M>) {
            self.item = item as! AreaItem
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.valueView.delegate = self.item
            self.valueView => \.font => Theme.current.font.mono
            self.valueView => \.textColor => Theme.current.color.body
            self.valueView.backgroundColor = .clear
            return self.valueView
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()

            if let window = self.valueView.window {
                self.valueView.heightAnchor.constraint( equalTo: window.heightAnchor, multiplier: .long )
                                           .with( priority: .defaultHigh ).isActive = true
            }
        }

        override func update() {
            super.update()

            self.valueView.isEditable = self.item.update != nil

            let value = self.item.value
            if let value = value as? NSAttributedString {
                self.valueView.attributedText = value
                self.valueView.isHidden = false
            }
            else if let value = value {
                self.valueView.text = String( describing: value )
                self.valueView.isHidden = false
            }
            else {
                self.valueView.text = nil
                self.valueView.attributedText = nil
                self.valueView.isHidden = true
            }
        }
    }
}

class StepperItem<M, V: AdditiveArithmetic & Comparable & CustomStringConvertible>: ValueItem<M, V> {
    let update: (M, V) -> Void
    let step:   V, min: V, max: V

    init(title: String? = nil, subitems: [Item<M>] = [],
         value: @escaping (M) -> V? = { _ in nil },
         update: @escaping (M, V) -> Void = { _, _ in },
         step: V, min: V, max: V,
         caption: @escaping (M) -> CustomStringConvertible? = { _ in nil }) {
        self.update = update
        self.step = step
        self.min = min
        self.max = max
        super.init( title: title, subitems: subitems, value: value, caption: caption )
    }

    override func createItemView() -> StepperItemView {
        StepperItemView( withItem: self )
    }

    class StepperItemView: ItemView {
        let item: StepperItem
        let valueView  = UIView()
        let valueLabel = UILabel()
        lazy var downButton = MPButton( attributedTitle: .icon( "" ), background: false ) { [unowned self]  _, _ in
            if let model = self.item.model, let value = self.item.value,
               value > self.item.min {
                self.item.update( model, value - self.item.step )
            }
        }
        lazy var upButton = MPButton( attributedTitle: .icon( "" ), background: false ) { [unowned self] _, _ in
            if let model = self.item.model, let value = self.item.value,
               value < self.item.max {
                self.item.update( model, value + self.item.step )
            }
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item<M>) {
            self.item = item as! StepperItem
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.valueLabel => \.font => Theme.current.font.largeTitle
            self.valueLabel.textAlignment = .center
            self.valueLabel => \.textColor => Theme.current.color.body
            self.valueLabel => \.shadowColor => Theme.current.color.shadow
            self.valueLabel.shadowOffset = CGSize( width: 0, height: 1 )

            self.valueView.addSubview( self.valueLabel )
            self.valueView.addSubview( self.downButton )
            self.valueView.addSubview( self.upButton )

            LayoutConfiguration( view: self.valueLabel )
                    .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                    .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                    .constrainTo { $1.centerXAnchor.constraint( equalTo: $0.centerXAnchor ) }
                    .constrainTo { $1.centerYAnchor.constraint( equalTo: $0.centerYAnchor ) }
                    .activate()
            LayoutConfiguration( view: self.downButton )
                    .constrainTo { $1.leadingAnchor.constraint( greaterThanOrEqualTo: $0.leadingAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( equalTo: self.valueLabel.leadingAnchor, constant: -20 ) }
                    .constrainTo { $1.centerYAnchor.constraint( equalTo: $0.centerYAnchor ) }
                    .activate()
            LayoutConfiguration( view: self.upButton )
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: self.valueLabel.trailingAnchor, constant: 20 ) }
                    .constrainTo { $1.trailingAnchor.constraint( lessThanOrEqualTo: $0.trailingAnchor ) }
                    .constrainTo { $1.centerYAnchor.constraint( equalTo: $0.centerYAnchor ) }
                    .activate()

            return self.valueView
        }

        override func update() {
            super.update()

            self.valueLabel.text = self.item.value?.description
        }
    }
}

class PickerItem<M, V: Hashable>: ValueItem<M, V> {
    let identifier: String
    let values:     (M) -> [V?]
    let update:     (M, V) -> Void

    init(identifier: String, title: String? = nil, values: @escaping (M) -> [V?], subitems: [Item<M>] = [],
         value: @escaping (M) -> V, update: @escaping (M, V) -> Void = { _, _ in },
         caption: @escaping (M) -> CustomStringConvertible? = { _ in nil }) {
        self.identifier = identifier
        self.values = values
        self.update = update

        super.init( title: title, subitems: subitems, value: value, caption: caption )
    }

    override func createItemView() -> PickerItemView {
        PickerItemView( withItem: self )
    }

    func didLoad(collectionView: UICollectionView) {
    }

    func cell(collectionView: UICollectionView, indexPath: IndexPath, model: M, value: V) -> UICollectionViewCell? {
        nil
    }

    func identifier(indexPath: IndexPath, model: M, value: V) -> String? {
        (value as? CustomStringConvertible)?.description
    }

    class PickerItemView: ItemView, UICollectionViewDelegate {
        let item: PickerItem<M, V>
        let collectionView = PickerView()
        lazy var dataSource = PickerSource( view: self )

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item<M>) {
            self.item = item as! PickerItem<M, V>
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.collectionView.delegate = self
            self.collectionView.dataSource = self.dataSource
            return self.collectionView
        }

        override func didLoad() {
            super.didLoad()

            self.item.didLoad( collectionView: self.collectionView )
        }

        override func update() {
            super.update()

            let values = self.item.model.flatMap { self.item.values( $0 ) } ?? []
            self.dataSource.update( values.split( separator: nil ).map( { [ V? ]( $0 ) } ) ) { [unowned self] _ in
                DispatchQueue.main.async {
                    self.updateSelection()
                }
            }
        }

        // MARK: --- Private ---

        private func updateSelection(animated: Bool = UIView.areAnimationsEnabled) {
            if let model = self.item.model,
               let selectedValue = self.item.valueProvider( model ),
               let selectedIndexPath = self.dataSource.indexPath( for: selectedValue ) {
                if self.collectionView.indexPathsForSelectedItems == [ selectedIndexPath ] {
                    self.collectionView.scrollToItem( at: selectedIndexPath, at: .centeredHorizontally, animated: animated )
                }
                else {
                    self.collectionView.selectItem( at: selectedIndexPath, animated: animated, scrollPosition: .centeredHorizontally )
                }
            }
        }

        // MARK: --- UICollectionViewDelegate ---

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            if let model = self.item.model, let value = self.dataSource.element( at: indexPath ) {
                if let itemIdentifier = self.item.identifier( indexPath: indexPath, model: model, value: value ) {
                    MPTracker.shared.event( named: self.item.identifier, [ "value": itemIdentifier ] )
                }

                self.item.update( model, value )
            }
        }

        class PickerSource: DataSource<V> {
            let view: PickerItemView

            init(view: PickerItemView) {
                self.view = view
                super.init( collectionView: view.collectionView )
            }

            override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
                self.view.item.cell( collectionView: collectionView, indexPath: indexPath,
                                     model: self.view.item.model!, value: self.element( at: indexPath )! )!
            }
        }

        class PickerView: UICollectionView {
            let layout = PickerLayout()

            // MARK: --- State ---

            override var contentSize:          CGSize {
                didSet {
                    self.invalidateIntrinsicContentSize()
                }
            }
            override var intrinsicContentSize: CGSize {
                self.layout.collectionViewContentSize
            }

            // MARK: --- Life ---

            required init?(coder aDecoder: NSCoder) {
                fatalError( "init(coder:) is not supported for this class" )
            }

            init() {
                super.init( frame: UIScreen.main.bounds, collectionViewLayout: self.layout )

                self.backgroundColor = .clear
                self.register( Separator.self, decorationKind: "Separator" )
            }

            class PickerLayout: UICollectionViewLayout {
                private var attributes      = [ UICollectionView.ElementCategory: [ IndexPath: UICollectionViewLayoutAttributes ] ]()
                private var initialPaths    = [ UICollectionView.ElementCategory: [ IndexPath ] ]()
                private let initialItemSize = CGSize( width: 50, height: 50 )
                private let spacing         = CGFloat( 12 )

                private lazy var  contentSize = self.initialItemSize {
                    didSet {
                        self.collectionView?.invalidateIntrinsicContentSize()
                    }
                }
                open override var collectionViewContentSize: CGSize {
                    self.contentSize
                }

                open override func prepare() {
                    super.prepare()

                    let margins         = self.collectionView?.layoutMargins ?? .zero
                    var offset          = margins.left, height = CGFloat( 0 )
                    var initialItemSize = self.initialItemSize, initialSeparatorSize = initialItemSize
                    initialSeparatorSize.width = 1

                    let sections = self.collectionView?.numberOfSections ?? 0
                    for section in 0..<sections {
                        for item in 0..<(self.collectionView?.numberOfItems( inSection: section ) ?? 0) {
                            self.prepareAttributes(
                                    path: IndexPath( item: item, section: section ), category: .cell,
                                    initialSize: &initialItemSize, margins: margins, offset: &offset, height: &height )
                        }
                        if section < sections - 1 {
                            self.prepareAttributes(
                                    path: IndexPath( item: 0, section: section ), category: .decorationView,
                                    initialSize: &initialSeparatorSize, margins: margins, offset: &offset, height: &height )
                        }
                    }

                    self.contentSize = CGSize( width: offset + (margins.right), height: height + (margins.bottom) )

                    height = ((self.contentSize.height - (margins.height)) * .long).rounded( .towardZero )
                    self.attributes[.decorationView]?.values.forEach {
                        $0.frame.size.height = height
                        $0.frame.origin.y = (self.contentSize.height - height) / 2
                    }
                }

                func prepareAttributes(path: IndexPath, category: UICollectionView.ElementCategory, initialSize: inout CGSize,
                                       margins: UIEdgeInsets, offset: inout CGFloat, height: inout CGFloat) {
                    if !(self.attributes[category]?.keys.contains( path ) ?? false) {
                        self.initialPaths[category, default: .init()].append( path )
                    }

                    let attributes = self.attributes[category, default: .init()][path, default: {
                        switch category {
                            case .cell:
                                return UICollectionViewLayoutAttributes( forCellWith: path )
                            case .decorationView:
                                return UICollectionViewLayoutAttributes( forDecorationViewOfKind: "Separator", with: path )
                            default:
                                return nil
                        }
                    }()!]

                    if self.initialPaths[category]?.contains( path ) ?? false {
                        attributes.frame.size = initialSize
                    }
                    else {
                        initialSize = attributes.size
                    }

                    attributes.frame.origin = CGPoint( x: offset == margins.left ? offset: offset + spacing, y: margins.top )
                    height = max( height, attributes.frame.maxY )
                    offset = attributes.frame.maxX
                }

                open override func shouldInvalidateLayout(forPreferredLayoutAttributes preferredAttributes: UICollectionViewLayoutAttributes,
                                                          withOriginalAttributes originalAttributes: UICollectionViewLayoutAttributes) -> Bool {
                    if let currentAttributes = self.attributes[originalAttributes.representedElementCategory]?[originalAttributes.indexPath],
                       currentAttributes.size != preferredAttributes.size {
                        currentAttributes.size = preferredAttributes.size
                        self.initialPaths[originalAttributes.representedElementCategory]?.removeAll { $0 == currentAttributes.indexPath }
                        return true
                    }

                    return false
                }

                open override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
                    self.attributes.values.flatMap( { $0.values } ).filter( { rect.intersects( $0.frame ) } )
                }

                open override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
                    self.attributes[.cell]?[indexPath]
                }

                override func layoutAttributesForDecorationView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
                    self.attributes[.decorationView]?[indexPath]
                }

                open override func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
                    self.attributes[.cell]?[itemIndexPath]
                }

                override func initialLayoutAttributesForAppearingDecorationElement(ofKind elementKind: String, at decorationIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
                    self.attributes[.decorationView]?[decorationIndexPath]
                }
            }

            class Separator: UICollectionReusableView {
                required init?(coder aDecoder: NSCoder) {
                    fatalError( "init(coder:) is not supported for this class" )
                }

                override init(frame: CGRect) {
                    super.init( frame: frame )

                    self => \.backgroundColor => Theme.current.color.mute
                }

                override var intrinsicContentSize: CGSize {
                    CGSize( width: 1, height: 1 )
                }
            }
        }
    }
}

class ListItem<M, V: Hashable>: Item<M> {
    let values: (M) -> [V]
    var deletable = false

    init(title: String? = nil, values: @escaping (M) -> [V], subitems: [Item<M>] = [],
         caption: @escaping (M) -> CustomStringConvertible? = { _ in nil }) {
        self.values = values

        super.init( title: title, subitems: subitems, caption: caption )
    }

    func didLoad(tableView: UITableView) {
    }

    func cell(tableView: UITableView, indexPath: IndexPath, model: M, value: V) -> UITableViewCell? {
        nil
    }

    func delete(model: M, value: V) {
    }

    override func createItemView() -> ListItemView {
        ListItemView( withItem: self )
    }

    class ListItemView: ItemView, UITableViewDelegate {
        let item: ListItem<M, V>
        let tableView         = TableView()
        let activityIndicator = UIActivityIndicatorView( style: .whiteLarge )
        lazy var dataSource = ListSource( view: self )

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item<M>) {
            self.item = item as! ListItem<M, V>
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.tableView.delegate = self
            self.tableView.dataSource = self.dataSource
            self.tableView.tableHeaderView = self.activityIndicator
            self.activityIndicator.startAnimating()
            return self.tableView
        }

        override func didLoad() {
            super.didLoad()

            self.item.didLoad( tableView: self.tableView )
        }

        override func update() {
            super.update()

            self.tableView.isHidden = false
            self.tableView.tableHeaderView = self.activityIndicator

            DispatchQueue.mpw.perform {
                self.dataSource.update( [ self.item.model.flatMap { self.item.values( $0 ) } ?? [] ], completion: { finished in
                    if finished {
                        self.tableView.isHidden = self.dataSource.isEmpty
                        self.tableView.tableHeaderView = nil
                    }
                } )
            }
        }

        // MARK: --- UITableViewDelegate ---

        // MARK: --- Types ---

        class ListSource: DataSource<V> {
            let view: ListItemView

            init(view: ListItemView) {
                self.view = view
                super.init( tableView: view.tableView )
            }

            override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
                self.view.item.cell( tableView: tableView, indexPath: indexPath,
                                     model: self.view.item.model!, value: self.element( at: indexPath )! )!
            }

            override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
                self.view.item.deletable
            }

            override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
                if editingStyle == .delete, self.view.item.deletable,
                   let model = self.view.item.model, let value = self.element( at: indexPath ) {
                    self.view.item.delete( model: model, value: value )
                }
            }
        }

        class TableView: UITableView {

            // MARK: --- State ---

            override var bounds:               CGRect {
                didSet {
                    if self.bounds.size.height < self.contentSize.height {
                        if !self.isScrollEnabled {
                            self.isScrollEnabled = true
                            self.flashScrollIndicators()
                        }
                    }
                    else {
                        self.isScrollEnabled = false
                    }
                }
            }
            override var contentSize:          CGSize {
                didSet {
                    self.invalidateIntrinsicContentSize()
                }
            }
            override var intrinsicContentSize: CGSize {
                CGSize( width: UIView.noIntrinsicMetric, height: max( 1, self.contentSize.height ) )
            }

            // MARK: --- Life ---

            required init?(coder aDecoder: NSCoder) {
                fatalError( "init(coder:) is not supported for this class" )
            }

            init() {
                super.init( frame: .zero, style: .plain )
                self.backgroundColor = .clear
                self.separatorStyle = .none
            }
        }
    }
}
