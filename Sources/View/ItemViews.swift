//
// Created by Maarten Billemont on 2019-04-26.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit
import SafariServices

class AnyItem: NSObject, Updatable {
    let title: String?

    private lazy var updateTask = DispatchTask( named: self.title, deadline: .now() + .milliseconds( 100 ), update: self, animated: true )

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
    public weak var viewController: ItemsViewController<M>? {
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
    private let subitemAxis:     NSLayoutConstraint.Axis
    private (set) lazy var view = createItemView()

    var updatesPostponed: Bool {
        self.viewController?.updatesPostponed ?? true
    }

    init(title: String? = nil,
         subitems: [Item<M>] = [], axis subitemAxis: NSLayoutConstraint.Axis = .horizontal,
         caption captionProvider: @escaping (M) -> CustomStringConvertible? = { _ in nil }) {
        self.subitems = subitems
        self.subitemAxis = subitemAxis
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

            self.subitemsStack.preservesSuperviewLayoutMargins = true
            self.subitemsStack.isLayoutMarginsRelativeArrangement = true

            self.captionLabel => \.textColor => Theme.current.color.secondary
            self.captionLabel.textAlignment = .center
            self.captionLabel => \.font => Theme.current.font.caption1
            self.captionLabel.numberOfLines = 0
            self.captionLabel.setContentHuggingPriority( .defaultHigh, for: .vertical )

            // - Hierarchy
            self.addSubview( self.contentView )
            self.contentView.addArrangedSubview( MarginView( for: self.titleLabel, margins: .horizontal() ) )
            if let valueView = self.valueView {
                self.contentView.addArrangedSubview( valueView )
            }
            self.contentView.addArrangedSubview( self.subitemsStack )
            self.contentView.addArrangedSubview( MarginView( for: self.captionLabel, margins: .horizontal() ) )

            // - Layout
            LayoutConfiguration( view: self.contentView )
                    .constrain { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                    .constrain { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                    .constrain { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                    .constrain { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                    .activate()

            LayoutConfiguration( view: self.subitemsStack )
                    .constrain { $1.widthAnchor.constraint( equalTo: $0.widthAnchor ).with( priority: .defaultHigh ) }
                    .constrain { $1.heightAnchor.constraint( equalToConstant: 0 ).with( priority: .fittingSizeLevel ) }
                    .activate()
        }

        /** Create a custom view for rendering this item's value. */
        func createValueView() -> UIView? {
            nil
        }

        /** The view was loaded and added to the view hierarchy. */
        func didLoad() {
            if let valueView = self.valueView {
                valueView.superview?.readableContentGuide.widthAnchor
                        .constraint( equalTo: valueView.widthAnchor ).with( priority: .defaultLow + 1 ).isActive = true
            }

            self.item.subitems.forEach { $0.view.didLoad() }
        }

        // MARK: --- Updatable ---

        func update() {
            updateHidden( self.item.behaviours.reduce( false ) { $0 || ($1.isHidden( item: self.item ) ?? $0) } )
            updateEnabled( self.item.behaviours.reduce( true ) { $0 && ($1.isEnabled( item: self.item ) ?? $0) } )

            self.titleLabel.text = self.item.title
            self.titleLabel.isHidden = self.item.title == nil

            self.captionLabel.text = self.item.model.flatMap { self.item.captionProvider( $0 )?.description }
            self.captionLabel.isHidden = self.captionLabel.text == nil

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
            self.subitemsStack.axis = self.item.subitemAxis

            switch self.item.subitemAxis {
                case .horizontal:
                    self.subitemsStack.alignment = .lastBaseline
                    self.subitemsStack.distribution = .fillEqually
                    self.subitemsStack.spacing = 20

                case .vertical: fallthrough
                @unknown default:
                    self.subitemsStack.alignment = .fill
                    self.subitemsStack.distribution = .fill
                    self.subitemsStack.spacing = 20
            }
        }

        func updateHidden(_ hidden: Bool) {
            self.isHidden = hidden
        }

        func updateEnabled(_ enabled: Bool) {
            self.alpha = enabled ? .on: .short
            self.contentView.isUserInteractionEnabled = enabled
            self.tintAdjustmentMode = enabled ? .automatic: .dimmed
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

class ColorizeBehaviour<M>: Behaviour<M> {
    let color:     UIColor
    let condition: (M) -> Bool

    init(color: UIColor, condition: @escaping (M) -> Bool) {
        self.color = color
        self.condition = condition
        super.init()
    }

    override func didUpdate(item: Item<M>) {
        super.didUpdate( item: item )

        if let model = item.model, self.condition( model ) {
            item.view.tintColor = self.color
        }
        else {
            item.view.tintColor = nil
        }

        if let view = item.view as? FieldItem.FieldItemView {
            if let tintColor = item.view.tintColor {
                (view.valueField => \.textColor).unbind()
                view.valueField.textColor = tintColor
            }
            else {
                view.valueField => \.textColor => Theme.current.color.body
            }
        }
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
        TapEffectView().run( for: item.view )
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

        super.doTapped( item: item )
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

class RequiresDebug<M>: ConditionalBehaviour<M> {
    init(mode: Effect) {
        super.init( mode: mode, condition: { _ in appConfig.isDebug } )
    }
}

class RequiresPrivate<M>: ConditionalBehaviour<M> {
    init(mode: Effect) {
        super.init( mode: mode, condition: { _ in !appConfig.isPublic } )
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
            self.separatorView
        }

        override func didLoad() {
            super.didLoad()

            self.separatorView => \.backgroundColor => Theme.current.color.mute
            self.separatorView.heightAnchor.constraint( equalToConstant: 1 ).isActive = true
        }
    }
}

class ValueItem<M, V>: Item<M> {
    let valueProvider: (M) -> V?
    var value: V? {
        self.model.flatMap { self.valueProvider( $0 ) }
    }
    let update: ((M, V) -> Void)?

    init(title: String? = nil,
         value valueProvider: @escaping (M) -> V? = { _ in nil },
         update: ((M, V) -> Void)? = nil,
         subitems: [Item<M>] = [], axis subitemAxis: NSLayoutConstraint.Axis = .horizontal,
         caption: @escaping (M) -> CustomStringConvertible? = { _ in nil }) {
        self.valueProvider = valueProvider
        self.update = update
        super.init( title: title, subitems: subitems, axis: subitemAxis, caption: caption )
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
            self.valueLabel
        }

        override func didLoad() {
            super.didLoad()

            self.valueLabel => \.font => Theme.current.font.largeTitle
            self.valueLabel.textAlignment = .center
            self.valueLabel => \.textColor => Theme.current.color.body
            self.valueLabel => \.shadowColor => Theme.current.color.shadow
            self.valueLabel.shadowOffset = CGSize( width: 0, height: 1 )
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
            self.valueImage
        }

        override func didLoad() {
            super.didLoad()

            self.valueImage.contentMode = .scaleAspectFit
            self.valueImage.setContentHuggingPriority( .defaultHigh, for: .horizontal )
            self.valueImage.setContentHuggingPriority( .defaultHigh, for: .vertical )
        }

        override func update() {
            super.update()

            self.valueImage.image = self.item.value
            self.valueImage.isHidden = self.valueImage.image == nil
        }
    }
}

class ToggleItem<M>: ValueItem<M, Bool> {
    let tracking: Tracking
    let icon:     (M) -> UIImage?

    init(track: Tracking, title: String? = nil,
         icon: @escaping (M) -> UIImage?,
         value: @escaping (M) -> Bool,
         update: ((M, Bool) -> ())? = nil,
         subitems: [Item<M>] = [], axis subitemAxis: NSLayoutConstraint.Axis = .horizontal,
         caption: @escaping (M) -> CustomStringConvertible? = { _ in nil }) {
        self.tracking = track
        self.icon = icon

        super.init( title: title, value: value, update: update, subitems: subitems, axis: subitemAxis, caption: caption )
    }

    override func createItemView() -> ToggleItemView {
        ToggleItemView( withItem: self )
    }

    class ToggleItemView: ItemView {
        let item: ToggleItem
        lazy var button = EffectToggleButton( track: self.item.tracking ) { [unowned self] isSelected in
            if let model = self.item.model {
                self.item.update?( model, isSelected )
            }

            return self.item.value ?? false
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item<M>) {
            self.item = item as! ToggleItem
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.button
        }

        override func update() {
            super.update()

            self.button.image = self.item.model.flatMap { self.item.icon( $0 ) }
            self.button.isSelected = self.item.value ?? false
        }

        override func updateEnabled(_ enabled: Bool) {
            self.button.isEnabled = enabled
        }
    }
}

class ButtonItem<M>: ValueItem<M, (label: String?, image: UIImage?)> {
    let tracking: Tracking
    let action:   (ButtonItem<M>) -> Void

    init(track: Tracking, title: String? = nil,
         value: @escaping (M) -> (label: String?, image: UIImage?),
         subitems: [Item<M>] = [], axis subitemAxis: NSLayoutConstraint.Axis = .horizontal,
         caption: @escaping (M) -> CustomStringConvertible? = { _ in nil },
         action: @escaping (ButtonItem<M>) -> () = { _ in }) {
        self.tracking = track
        self.action = action

        super.init( title: title, value: value, subitems: subitems, axis: subitemAxis, caption: caption )
    }

    override func createItemView() -> ButtonItemView {
        ButtonItemView( withItem: self )
    }

    class ButtonItemView: ItemView {
        let item: ButtonItem

        lazy var button = EffectButton( track: self.item.tracking ) { [unowned self] _, _ in
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
        let dateView  = DateView()

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item<M>) {
            self.item = item as! DateItem
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.valueView
        }

        override func didLoad() {
            super.didLoad()

            self.valueView.addSubview( self.dateView )

            LayoutConfiguration( view: self.dateView )
                    .constrain { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                    .constrain { $1.leadingAnchor.constraint( greaterThanOrEqualTo: $0.leadingAnchor ) }
                    .constrain { $1.trailingAnchor.constraint( lessThanOrEqualTo: $0.trailingAnchor ) }
                    .constrain { $1.centerXAnchor.constraint( equalTo: $0.centerXAnchor ) }
                    .constrain { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                    .activate()
        }

        override func update() {
            super.update()

            self.dateView.date = self.item.value
        }
    }
}

class FieldItem<M>: ValueItem<M, String>, UITextFieldDelegate {
    let placeholder: String?

    init(title: String? = nil, placeholder: String?,
         value: @escaping (M) -> String? = { _ in nil },
         update: ((M, String) -> ())? = nil,
         subitems: [Item<M>] = [], axis subitemAxis: NSLayoutConstraint.Axis = .horizontal,
         caption: @escaping (M) -> CustomStringConvertible? = { _ in nil }) {
        self.placeholder = placeholder
        super.init( title: title, value: value, update: update, subitems: subitems, axis: subitemAxis, caption: caption )
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
            self.valueField
        }

        override func didLoad() {
            super.didLoad()

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
        }

        override func update() {
            super.update()

            self.valueField.placeholder = self.item.placeholder
            self.valueField.text = self.item.value
        }
    }
}

class AreaItem<M, V>: ValueItem<M, V>, UITextViewDelegate {

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
            self.valueView
        }

        override func didLoad() {
            super.didLoad()

            self.valueView.delegate = self.item
            self.valueView => \.font => Theme.current.font.mono
            self.valueView => \.textColor => Theme.current.color.body
            self.valueView.backgroundColor = .clear
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
    let step: V, min: V, max: V

    init(title: String? = nil,
         value: @escaping (M) -> V? = { _ in nil },
         update: ((M, V) -> ())? = nil,
         step: V, min: V, max: V,
         subitems: [Item<M>] = [], axis subitemAxis: NSLayoutConstraint.Axis = .horizontal,
         caption: @escaping (M) -> CustomStringConvertible? = { _ in nil }) {
        self.step = step
        self.min = min
        self.max = max
        super.init( title: title, value: value, update: update, subitems: subitems, axis: subitemAxis, caption: caption )
    }

    override func createItemView() -> StepperItemView {
        StepperItemView( withItem: self )
    }

    class StepperItemView: ItemView {
        let item: StepperItem
        let valueView  = UIView()
        let valueLabel = UILabel()
        lazy var downButton = EffectButton( attributedTitle: .icon( "" ), background: false ) { [unowned self]  _, _ in
            if let model = self.item.model, let value = self.item.value, value > self.item.min {
                self.item.update?( model, value - self.item.step )
            }
        }
        lazy var upButton = EffectButton( attributedTitle: .icon( "" ), background: false ) { [unowned self] _, _ in
            if let model = self.item.model, let value = self.item.value, value < self.item.max {
                self.item.update?( model, value + self.item.step )
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
            self.valueView
        }

        override func didLoad() {
            super.didLoad()

            self.valueLabel => \.font => Theme.current.font.largeTitle
            self.valueLabel.textAlignment = .center
            self.valueLabel => \.textColor => Theme.current.color.body
            self.valueLabel => \.shadowColor => Theme.current.color.shadow
            self.valueLabel.shadowOffset = CGSize( width: 0, height: 1 )

            self.valueView.addSubview( self.valueLabel )
            self.valueView.addSubview( self.downButton )
            self.valueView.addSubview( self.upButton )

            LayoutConfiguration( view: self.valueLabel )
                    .constrain { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                    .constrain { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                    .constrain { $1.centerXAnchor.constraint( equalTo: $0.centerXAnchor ) }
                    .constrain { $1.centerYAnchor.constraint( equalTo: $0.centerYAnchor ) }
                    .activate()
            LayoutConfiguration( view: self.downButton )
                    .constrain { $1.leadingAnchor.constraint( greaterThanOrEqualTo: $0.leadingAnchor ) }
                    .constrain { $1.trailingAnchor.constraint( equalTo: self.valueLabel.leadingAnchor, constant: -20 ) }
                    .constrain { $1.centerYAnchor.constraint( equalTo: $0.centerYAnchor ) }
                    .activate()
            LayoutConfiguration( view: self.upButton )
                    .constrain { $1.leadingAnchor.constraint( equalTo: self.valueLabel.trailingAnchor, constant: 20 ) }
                    .constrain { $1.trailingAnchor.constraint( lessThanOrEqualTo: $0.trailingAnchor ) }
                    .constrain { $1.centerYAnchor.constraint( equalTo: $0.centerYAnchor ) }
                    .activate()
        }

        override func update() {
            super.update()

            self.valueLabel.text = self.item.value?.description
        }
    }
}

class PickerItem<M, V: Hashable, C: UICollectionViewCell>: ValueItem<M, V> {
    let tracking: Tracking?
    let values:   (M) -> [V?]

    init(track: Tracking? = nil, title: String? = nil,
         values: @escaping (M) -> [V?],
         value: @escaping (M) -> V,
         update: ((M, V) -> ())? = nil,
         subitems: [Item<M>] = [], axis subitemAxis: NSLayoutConstraint.Axis = .horizontal,
         caption: @escaping (M) -> CustomStringConvertible? = { _ in nil }) {
        self.tracking = track
        self.values = values

        super.init( title: title, value: value, update: update, subitems: subitems, axis: subitemAxis, caption: caption )
    }

    override func createItemView() -> PickerItemView {
        PickerItemView( withItem: self )
    }

    func populate(_ cell: C, indexPath: IndexPath, value: V) {
    }

    func tracking(indexPath: IndexPath, value: V) -> Tracking? {
        if let tracking = self.tracking, let value = (value as? CustomStringConvertible)?.description {
            return tracking.with( parameters: [ "value": value ] )
        }

        return self.tracking
    }

    class PickerItemView: ItemView, UICollectionViewDelegate {
        let item: PickerItem
        let collectionView = PickerView()
        lazy var dataSource = PickerSource( view: self )

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item<M>) {
            self.item = item as! PickerItem
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.collectionView
        }

        override func didLoad() {
            super.didLoad()

            self.collectionView.register( C.self )
            self.collectionView.delegate = self
            self.collectionView.dataSource = self.dataSource
            self.updateDataSource()
        }

        func updateDataSource() {
            let values = self.item.model.flatMap { self.item.values( $0 ) } ?? []
            self.dataSource.update( values.split( separator: nil ).map( { $0.compactMap { $0 } } ) ) { [unowned self] _ in
                DispatchQueue.main.async {
                    self.updateSelection()
                }
            }
        }

        override func update() {
            super.update()

            self.updateDataSource()
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
                if let tracking = self.item.tracking( indexPath: indexPath, value: value ) {
                    Tracker.shared.event( track: tracking )
                }

                self.item.update?( model, value )
            }
        }

        class PickerSource: DataSource<V> {
            let view: PickerItemView

            init(view: PickerItemView) {
                self.view = view

                super.init( collectionView: view.collectionView )
            }

            override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
                using( C.dequeue( from: collectionView, indexPath: indexPath ) ) {
                    self.view.item.populate( $0, indexPath: indexPath, value: self.element( at: indexPath )! )
                }
            }
        }
    }
}

class PagerItem<M>: ValueItem<M, [Item<M>]> {
    override var model: M? {
        didSet {
            (self.view as? PagerItemView)?.pageItems.forEach { $0.model = self.model }
        }
    }

    override func createItemView() -> PagerItemView {
        PagerItemView( withItem: self )
    }

    class PagerItemView: ItemView {
        let item: PagerItem
        let pagerView = PagerView()
        lazy var pageItems = self.item.value ?? []

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item<M>) {
            self.item = item as! PagerItem
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.pagerView
        }

        override func didLoad() {
            super.didLoad()

            self.pageItems.forEach { $0.model = self.item.model }
            self.pagerView.pages = self.pageItems.map { $0.view }
            self.pageItems.forEach { $0.view.didLoad() }
            self.pageItems.forEach { $0.update() } // TODO: self.update?
        }

        override func update() {
            super.update()

            self.pageItems.forEach { $0.update() }
        }
    }
}

class ListItem<M, V: Hashable, C: UITableViewCell>: Item<M> {
    let values: (M) -> [V]
    var deletable = false

    init(title: String? = nil,
         values: @escaping (M) -> [V],
         subitems: [Item<M>] = [], axis subitemAxis: NSLayoutConstraint.Axis = .horizontal,
         caption: @escaping (M) -> CustomStringConvertible? = { _ in nil }) {
        self.values = values

        super.init( title: title, subitems: subitems, axis: subitemAxis, caption: caption )
    }

    func populate(_ cell: C, indexPath: IndexPath, value: V) {
    }

    func delete(indexPath: IndexPath, value: V) {
    }

    override func createItemView() -> ListItemView {
        ListItemView( withItem: self )
    }

    class ListItemView: ItemView, UITableViewDelegate {
        let item: ListItem
        let tableView         = TableView()
        let activityIndicator = UIActivityIndicatorView( style: .whiteLarge )
        lazy var dataSource = ListSource( view: self )

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item<M>) {
            self.item = item as! ListItem
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.tableView
        }

        override func didLoad() {
            super.didLoad()

            self.tableView.register( C.self )
            self.tableView.delegate = self
            self.tableView.dataSource = self.dataSource
            self.tableView.tableHeaderView = self.activityIndicator
            self.activityIndicator.startAnimating()
        }

        override func update() {
            super.update()

            self.tableView.isHidden = false
            self.tableView.tableHeaderView = self.activityIndicator

            DispatchQueue.api.perform {
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
                using( C.dequeue( from: tableView, indexPath: indexPath ) ) {
                    self.view.item.populate( $0, indexPath: indexPath, value: self.element( at: indexPath )! )
                }
            }

            override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
                self.view.item.deletable
            }

            override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
                if editingStyle == .delete, self.view.item.deletable, let value = self.element( at: indexPath ) {
                    self.view.item.delete( indexPath: indexPath, value: value )
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

class LinksItem<M>: ListItem<M, LinksItem.Link, LinksItem.Cell> {

    override func populate(_ cell: Cell, indexPath: IndexPath, value: Link) {
        cell.item = self
        cell.link = value
    }

    struct Link: Hashable {
        let title: String
        let url:   URL?
    }

    class Cell: UITableViewCell {
        var item: LinksItem?
        var link: Link? {
            didSet {
                DispatchQueue.main.perform {
                    self.button.setTitle( self.link?.title, for: .normal )
                }
            }
        }

        private let button = UIButton()

        // MARK: --- Life ---

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init( style: style, reuseIdentifier: reuseIdentifier )

            // - View
            self.isOpaque = false
            self.backgroundColor = .clear

            self.button => \.titleLabel!.font => Theme.current.font.callout
            self.button => \.currentTitleColor => Theme.current.color.body
            self.button => \.currentTitleShadowColor => Theme.current.color.shadow
            self.button.titleLabel!.shadowOffset = CGSize( width: 0, height: 1 )
            self.button.action( for: .primaryActionTriggered ) { [unowned self] in
                if let url = self.link?.url {
                    trc( "Opening link: %@", url )

                    self.item?.viewController?.present( SFSafariViewController( url: url ), animated: true )
                }
            }

            // - Hierarchy
            self.contentView.addSubview( self.button )

            // - Layout
            LayoutConfiguration( view: self.button ).constrain( as: .box )
                                                    .activate()
        }
    }
}
