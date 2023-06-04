// =============================================================================
// Created by Maarten Billemont on 2019-04-26.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import UIKit
import SafariServices

// swiftlint:disable file_length
@MainActor
class AnyItem: NSObject, Updatable {
    let title: Message?

    init(title: Message? = nil) {
        self.title = title
        super.init()
        LeakRegistry.shared.register( self )
    }

    lazy var updateTask = DispatchTask.update( self, animated: true ) { [weak self] in
        guard let self = self
        else { return }

        await self.doUpdate()
    }

    @MainActor
    func doUpdate() async {
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

            self.updateTask.request()
        }
    }
    private var behaviours = [ Behaviour<M> ]()

    private let captionProvider: (M) async -> Message?
    private let subitems:        [Item<M>]
    private let subitemAxis:     NSLayoutConstraint.Axis
    private (set) lazy var view = createItemView()

    var updatesPostponed: Bool {
        self.viewController?.updatesPostponed ?? true
    }

    init(title: Message? = nil,
         subitems: [Item<M>] = [], axis subitemAxis: NSLayoutConstraint.Axis = .horizontal,
         caption captionProvider: @escaping (M) async -> Message? = { _ in nil }) {
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

    // MARK: - Updatable

    override func doUpdate() async {
        await super.doUpdate()

        await self.view.doUpdate()
        for behaviour in self.behaviours {
            await behaviour.doUpdate( item: self )
        }

        for item in self.subitems {
            try? await item.updateTask.requestNow()
        }
    }

    // MARK: - Types

    enum SubItemMode {
        case inline, pager
    }

    class ItemView: BaseView {
        let titleLabel    = UILabel()
        let captionLabel  = UILabel()
        let contentView   = UIStackView()
        let subitemsStack = UIStackView()

        private lazy var  valueView = self.createValueView()
        internal weak var item: Item<M>?

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
            self.contentView.spacing = 12
            self.contentView.insetsLayoutMarginsFromSafeArea = false

            self.titleLabel.numberOfLines = 0
            self.titleLabel => \.textColor => Theme.current.color.body
            self.titleLabel.textAlignment = .center
            self.titleLabel => \.font => Theme.current.font.headline
            self.titleLabel.setContentHuggingPriority( .defaultHigh, for: .vertical )

            self.subitemsStack.preservesSuperviewLayoutMargins = true
            self.subitemsStack.insetsLayoutMarginsFromSafeArea = false
            self.subitemsStack.isLayoutMarginsRelativeArrangement = true

            self.captionLabel.textAlignment = .center
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
            if let valueView = self.valueView, let superview = valueView.superview {
                valueView.widthAnchor.constraint( equalTo: superview.readableContentGuide.widthAnchor )
                         .with( priority: .defaultLow + 1 ).isActive = true
            }

            for item in self.item?.subitems ?? [] {
                item.view.didLoad()
            }
        }

        // MARK: - Updatable

        func doUpdate() async {
            guard let item = self.item
            else { return }

            self.updateHidden( await item.behaviours.async.compactMap { await $0.isHidden(item: item) }.reduce( false ) { $0 || $1 } )
            self.updateEnabled( await item.behaviours.async.compactMap { await $0.isEnabled(item: item) }.reduce( false ) { $0 && $1 } )

            self.titleLabel.applyText( item.title )
            self.titleLabel.isHidden = self.titleLabel.attributedText?.string.nonEmpty == nil

            self.captionLabel.attributedText = await item.model.flatMap { await item.captionProvider( $0 ) }?.attributedString
            self.captionLabel => \.attributedText => .font => Theme.current.font.caption1
            self.captionLabel => \.attributedText => .foregroundColor => Theme.current.color.secondary
            self.captionLabel.isHidden = self.captionLabel.attributedText?.length == .zero

            for i in 0..<max( item.subitems.count, self.subitemsStack.arrangedSubviews.count ) {
                let subitemView  = i < item.subitems.count ? item.subitems[i].view : nil
                let arrangedView = i < self.subitemsStack.arrangedSubviews.count ? self.subitemsStack.arrangedSubviews[i] : nil

                if arrangedView != subitemView {
                    arrangedView?.removeFromSuperview()

                    if let subitemView = subitemView {
                        self.subitemsStack.insertArrangedSubview( subitemView, at: i )
                    }
                }
            }
            self.subitemsStack.isHidden = self.subitemsStack.arrangedSubviews.count == 0
            self.subitemsStack.axis = item.subitemAxis

            switch item.subitemAxis {
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
            self.alpha = enabled ? .on : .short
            self.contentView.isUserInteractionEnabled = enabled
            self.tintAdjustmentMode = enabled ? .automatic : .dimmed
        }
    }
}

@MainActor
class Behaviour<M> {
    private let hiddenProvider:  ((M) async -> Bool)?
    private let enabledProvider: ((M) async -> Bool)?
    private var items = [ WeakBox<Item<M>> ]()

    init(hidden hiddenProvider: ((M) async -> Bool)? = nil, enabled enabledProvider: ((M) async -> Bool)? = nil) {
        self.hiddenProvider = hiddenProvider
        self.enabledProvider = enabledProvider
        LeakRegistry.shared.register( self )
    }

    func didInstall(into item: Item<M>) {
        self.items.append( WeakBox( item ) )
    }

    func doUpdate(item: Item<M>) async {
    }

    func setNeedsUpdate() {
        self.items.forEach { $0.value?.updateTask.request() }
    }

    func isHidden(item: Item<M>) async -> Bool? {
        if let model = item.model, let hiddenProvider = self.hiddenProvider {
            return await hiddenProvider( model )
        }

        return nil
    }

    func isEnabled(item: Item<M>) async -> Bool? {
        if let model = item.model, let enabledProvider = self.enabledProvider {
            return await enabledProvider( model )
        }

        return nil
    }
}

class ColorizeBehaviour<M>: Behaviour<M> {
    let color:     UIColor
    let condition: (M) async -> Bool

    init(color: UIColor, condition: @escaping (M) async -> Bool) {
        self.color = color
        self.condition = condition
        super.init()
    }

    override func doUpdate(item: Item<M>) async {
        await super.doUpdate( item: item )

        if let model = item.model, await self.condition( model ) {
            item.view.tintColor = self.color
        }
        else {
            item.view.tintColor = nil
        }

        if let view = item.view as? FieldItem.FieldItemView {
            if let tintColor = item.view.tintColor {
                view.valueField => \.textColor => nil
                view.valueField.textColor = tintColor
            }
            else {
                view.valueField => \.textColor => Theme.current.color.body
            }
        }
    }
}

class TapBehaviour<M>: Behaviour<M> {
    var tapRecognizers = [ UIGestureRecognizer: WeakBox<Item<M>> ]()
    var isEnabled = true {
        didSet {
            self.tapRecognizers.forEach {
                $0.key.isEnabled = self.isEnabled
                $0.value.value?.view.contentView.isUserInteractionEnabled = !self.isEnabled
            }
        }
    }

    override func didInstall(into item: Item<M>) {
        super.didInstall( into: item )

        let tapRecognizer = UITapGestureRecognizer { [unowned self] in
            if let item = self.tapRecognizers[$0]?.value, $0.state == .ended {
                self.doTapped( item: item )
            }
        }
        tapRecognizer.name = _describe( type( of: self ) )
        tapRecognizer.isEnabled = self.isEnabled
        self.tapRecognizers[tapRecognizer] = WeakBox( item )
        item.view.addGestureRecognizer( tapRecognizer )
        item.view.contentView.isUserInteractionEnabled = !self.isEnabled
    }

    func doTapped(item: Item<M>) {
        TapEffectView().run( for: item.view )
    }
}

class BlockTapBehaviour<M>: TapBehaviour<M> {
    let enabled: @MainActor (Item<M>) async -> Bool
    let tapped:  @MainActor (Item<M>) async -> Void

    init(enabled: @escaping @MainActor (Item<M>) async -> Bool = { _ in true }, _ tapped: @escaping @MainActor (Item<M>) async -> Void) {
        self.enabled = enabled
        self.tapped = tapped

        super.init()
    }

    override func doUpdate(item: Item<M>) async {
        await super.doUpdate( item: item )

        self.isEnabled = await self.enabled( item )
    }

    override func doTapped(item: Item<M>) {
        Task { @MainActor in await self.tapped( item ) }

        super.doTapped( item: item )
    }
}

/// An item is hidden if any one behaviour is hidden.
/// An item is disabled if any one behaviour is not enabled.
class ConditionalBehaviour<M>: Behaviour<M> {
    init(effect: Effect, condition: @escaping (M) async -> Bool) {
        super.init( hidden: { model in
            switch effect {
                case .enables:
                    return false
                case .reveals:
                    return await !condition( model )
                case .hides:
                    return await condition( model )
            }
        }, enabled: { model in
            switch effect {
                case .enables:
                    return await condition( model )
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

class IfDebug<M>: ConditionalBehaviour<M> {
    init(effect: Effect) {
        super.init( effect: effect, condition: { _ in AppConfig.shared.isDebug } )
    }
}

class IfConfiguration<M>: ConditionalBehaviour<M> {
    init(_ configuration: AppConfiguration, effect: Effect) {
        super.init( effect: effect, condition: { _ in AppConfig.shared.environment == configuration } )
    }
}

class SeparatorItem<M>: Item<M> {
    override func createItemView() -> ItemView {
        SeparatorItemView( withItem: self )
    }

    class SeparatorItemView: ItemView {
        let separatorView = UIView()

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
    let valueProvider: (M) async -> V?
    var value: V? {
        get async {
            await self.model.flatMap { await self.valueProvider( $0 ) }
        }
    }
    let update: (@MainActor (Item<M>, V) async -> Void)?

    init(title: Message? = nil,
         value valueProvider: @escaping (M) async -> V? = { _ in nil },
         update: (@MainActor (Item<M>, V) async -> Void)? = nil,
         subitems: [Item<M>] = [], axis subitemAxis: NSLayoutConstraint.Axis = .horizontal,
         caption: @escaping (M) async -> Message? = { _ in nil }) {
        self.valueProvider = valueProvider
        self.update = update
        super.init( title: title, subitems: subitems, axis: subitemAxis, caption: caption )
    }

    class ValueItemView: ItemView {
        var valueItem: ValueItem? {
            self.item as? ValueItem
        }
    }
}

class LabelItem<M>: ValueItem<M, Any> {
    override func createItemView() -> LabelItemView {
        LabelItemView( withItem: self )
    }

    class LabelItemView: ValueItemView {
        let valueLabel = UILabel()

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

        override func doUpdate() async {
            await super.doUpdate()

            let value = await self.valueItem?.value
            if let value = value as? NSAttributedString ?? (value as? Message)?.attributedString {
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

    class ImageItemView: ValueItemView {
        let valueImage = UIImageView()

        override func createValueView() -> UIView? {
            self.valueImage
        }

        override func didLoad() {
            super.didLoad()

            self.valueImage.contentMode = .scaleAspectFit
            self.valueImage.setContentHuggingPriority( .defaultHigh, for: .horizontal )
            self.valueImage.setContentHuggingPriority( .defaultHigh, for: .vertical )
        }

        override func doUpdate() async {
            await super.doUpdate()

            self.valueImage.image = await self.valueItem?.value
            self.valueImage.isHidden = self.valueImage.image == nil
        }
    }
}

class ToggleItem<M>: ValueItem<M, Bool> {
    let tracking: Tracking
    let icon:     (M) async -> UIImage?

    init(track: Tracking, title: Message? = nil,
         icon: @escaping (M) async -> UIImage?,
         value: @escaping (M) async -> Bool,
         update: ((Item<M>, Bool) async -> Void)? = nil,
         subitems: [Item<M>] = [], axis subitemAxis: NSLayoutConstraint.Axis = .horizontal,
         caption: @escaping (M) async -> Message? = { _ in nil }) {
        self.tracking = track
        self.icon = icon

        super.init( title: title, value: value, update: update, subitems: subitems, axis: subitemAxis, caption: caption )
    }

    override func createItemView() -> ToggleItemView {
        ToggleItemView( withItem: self )
    }

    class ToggleItemView: ValueItemView {
        var toggleItem: ToggleItem? {
            self.item as? ToggleItem
        }
        lazy var button = EffectToggleButton( track: self.toggleItem?.tracking ) { [unowned self] isSelected in
            await self.toggleItem.flatMap { await $0.update?( $0, isSelected ) }

            return await self.toggleItem?.value ?? false
        }

        override func createValueView() -> UIView? {
            self.button
        }

        override func doUpdate() async {
            await super.doUpdate()

            self.button.image = await self.toggleItem?.model.flatMap { await self.toggleItem?.icon( $0 ) }
            self.button.isSelected = await self.toggleItem?.value ?? false
        }

        override func updateEnabled(_ enabled: Bool) {
            super.updateEnabled( enabled )
            self.button.isEnabled = enabled
        }
    }
}

class ButtonItem<M>: ValueItem<M, (label: Message?, image: UIImage?)> {
    let tracking: Tracking
    let action:   (ButtonItem<M>) async -> Void

    init(track: Tracking, title: Message? = nil,
         value: @escaping (M) async -> (label: Message?, image: UIImage?),
         subitems: [Item<M>] = [], axis subitemAxis: NSLayoutConstraint.Axis = .horizontal,
         caption: @escaping (M) async -> Message? = { _ in nil },
         action: @escaping (ButtonItem<M>) async -> Void = { _ in }) {
        self.tracking = track
        self.action = action

        super.init( title: title, value: value, subitems: subitems, axis: subitemAxis, caption: caption )
    }

    override func createItemView() -> ButtonItemView {
        ButtonItemView( withItem: self )
    }

    class ButtonItemView: ValueItemView {
        var buttonItem: ButtonItem? {
            self.item as? ButtonItem
        }

        lazy var button = EffectButton( track: self.buttonItem?.tracking ) { [unowned self] _ in
            await self.buttonItem.flatMap { await $0.action( $0 ) }
        }

        override func createValueView() -> UIView? {
            self.button
        }

        override func doUpdate() async {
            await super.doUpdate()

            let value = await self.buttonItem?.value
            self.button.button.applyText( value?.label )
            self.button.image = value?.image
        }
    }
}

class DateItem<M>: ValueItem<M, Date> {
    override func createItemView() -> DateItemView {
        DateItemView( withItem: self )
    }

    class DateItemView: ValueItemView {
        let valueView = UIView()
        let dateView  = DateView()

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

        override func doUpdate() async {
            await super.doUpdate()

            self.dateView.date = await self.valueItem?.value
        }
    }
}

class FieldItem<M>: ValueItem<M, String>, UITextFieldDelegate {
    let placeholder: String?
    let contentType: UITextContentType?

    init(title: Message? = nil, placeholder: String?, contentType: UITextContentType? = nil,
         value: @escaping (M) async -> String? = { _ in nil },
         update: ((Item<M>, String) async -> Void)? = nil,
         subitems: [Item<M>] = [], axis subitemAxis: NSLayoutConstraint.Axis = .horizontal,
         caption: @escaping (M) async -> Message? = { _ in nil }) {
        self.placeholder = placeholder
        self.contentType = contentType
        super.init( title: title, value: value, update: update, subitems: subitems, axis: subitemAxis, caption: caption )
    }

    override func createItemView() -> FieldItemView {
        FieldItemView( withItem: self )
    }

    private var autocorrectionType: UITextAutocorrectionType {
        self.contentType == nil ? .default : .no
    }

    private var autocapitalizationType: UITextAutocapitalizationType {
        if [.postalCode, .telephoneNumber, .creditCardNumber, .oneTimeCode].contains(self.contentType) {
            return .allCharacters
        }
        else if #available(iOS 15, *), [.shipmentTrackingNumber, .flightNumber].contains(self.contentType) {
            return .allCharacters
        }
        else if [.emailAddress, .URL, .username, .password, .newPassword].contains(self.contentType) {
            return .none
        }
        else if self.contentType == nil {
            return .sentences
        }
        else {
            return .words
        }
    }

    private var keyboardType: UIKeyboardType {
        if [.telephoneNumber].contains(self.contentType) {
            return .phonePad
        }
        else if [.creditCardNumber].contains(self.contentType) {
            return .numberPad
        }
        else if [.oneTimeCode, .postalCode].contains(self.contentType) {
            return .namePhonePad
        }
        else if #available(iOS 15, *), [.shipmentTrackingNumber, .flightNumber].contains(self.contentType) {
            return .namePhonePad
        }
        else if [.emailAddress, .username].contains(self.contentType) {
            return .emailAddress
        }
        else if [.URL].contains(self.contentType) {
            return .URL
        }
        else if [.password, .newPassword].contains(self.contentType) {
            return .asciiCapable
        }
        else {
            return .default
        }
    }

    // MARK: UITextFieldDelegate

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        self.update != nil
    }

    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        guard let text = textField.text
        else { return }

        Task { await self.update?( self, text ) }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing( false )
        return true
    }

    class FieldItemView: ItemView {
        var fieldItem: FieldItem? {
            self.item as? FieldItem
        }
        let valueField = UITextField()

        override func createValueView() -> UIView? {
            self.valueField
        }

        override func didLoad() {
            super.didLoad()

            self.valueField.delegate = self.fieldItem
            self.valueField => \.font => Theme.current.font.mono
            self.valueField => \.textColor => Theme.current.color.body
            self.valueField.textAlignment = .center
        }

        override func doUpdate() async {
            await super.doUpdate()

            self.valueField.placeholder = self.fieldItem?.placeholder
            self.valueField.autocapitalizationType = self.fieldItem?.autocapitalizationType ?? .sentences
            self.valueField.autocorrectionType = self.fieldItem?.autocorrectionType ?? .default
            self.valueField.textContentType = self.fieldItem?.contentType
            self.valueField.keyboardType = self.fieldItem?.keyboardType ?? .default
            self.valueField.returnKeyType = .done
            self.valueField.text = await self.fieldItem?.value
        }
    }
}

class AreaItem<M, V>: ValueItem<M, V>, UITextViewDelegate {

    override func createItemView() -> AreaItemView {
        AreaItemView( withItem: self )
    }

    // MARK: UITextViewDelegate

    func textViewDidChange(_ textView: UITextView) {
        guard let update = self.update
        else { return }

        Task {
            if let value = textView.text as? V {
                await update( self, value )
            }
            else if let value = textView.attributedText as? V {
                await update( self, value )
            }
        }
    }

    class AreaItemView: ValueItemView {
        var areaItem: AreaItem? {
            self.item as? AreaItem
        }
        let valueView = UITextView()

        override func createValueView() -> UIView? {
            self.valueView
        }

        override func didLoad() {
            super.didLoad()

            self.valueView.delegate = self.areaItem
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

        override func doUpdate() async {
            await super.doUpdate()

            self.valueView.isEditable = self.areaItem?.update != nil

            let value = await self.areaItem?.value
            if let value = value as? NSAttributedString ?? (value as? Message)?.attributedString {
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

class StepperItem<M, V: Strideable & Comparable & CustomStringConvertible>: ValueItem<M, V> {
    let step: V.Stride, min: V, max: V

    init(title: Message? = nil,
         value: @escaping (M) async -> V? = { _ in nil },
         update: ((Item<M>, V) async -> Void)? = nil,
         step: V.Stride, min: V, max: V,
         subitems: [Item<M>] = [], axis subitemAxis: NSLayoutConstraint.Axis = .horizontal,
         caption: @escaping (M) async -> Message? = { _ in nil }) {
        self.step = step
        self.min = min
        self.max = max
        super.init( title: title, value: value, update: update, subitems: subitems, axis: subitemAxis, caption: caption )
    }

    override func createItemView() -> StepperItemView {
        StepperItemView( withItem: self )
    }

    class StepperItemView: ValueItemView {
        var stepperItem: StepperItem? {
            self.item as? StepperItem
        }
        let valueView  = UIView()
        let valueLabel = UILabel()
        lazy var downButton = EffectButton( attributedTitle: .icon( "caret-down" ), border: 0, background: false ) { [weak self] _ in
            if let stepperItem = self?.stepperItem, let value = await stepperItem.value, value > stepperItem.min {
                await stepperItem.update?( stepperItem, value.advanced( by: -stepperItem.step ) )
            }
        }
        lazy var upButton = EffectButton( attributedTitle: .icon( "caret-up" ), border: 0, background: false ) { [weak self] _ in
            if let stepperItem = self?.stepperItem, let value = await stepperItem.value, value < stepperItem.max {
                await stepperItem.update?( stepperItem, value.advanced( by: stepperItem.step ) )
            }
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

        override func doUpdate() async {
            await super.doUpdate()

            self.valueLabel.text = await self.stepperItem?.value?.description
        }
    }
}

class PickerItem<M, V: Hashable, C: UICollectionViewCell>: ValueItem<M, V> {
    let tracking: Tracking?
    let values:   @MainActor (M) async -> [V?]

    init(track: Tracking? = nil, title: Message? = nil,
         values: @escaping (M) async -> [V?],
         value: @escaping (M) async -> V,
         update: (@MainActor (Item<M>, V) async -> Void)? = nil,
         subitems: [Item<M>] = [], axis subitemAxis: NSLayoutConstraint.Axis = .horizontal,
         caption: @escaping (M) async -> Message? = { _ in nil }) {
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
        if let tracking = self.tracking, let value = (value as? Message)?.description {
            return tracking.with( parameters: [ "value": value ] )
        }

        return self.tracking
    }

    class PickerItemView: ValueItemView, UICollectionViewDelegate {
        var pickerItem: PickerItem? {
            self.item as? PickerItem
        }
        let collectionView = PickerView()
        var dataSource: DataSource<Int, V>?

        override func createValueView() -> UIView? {
            self.collectionView
        }

        override func didLoad() {
            super.didLoad()

            self.collectionView.register( C.self )
            self.collectionView.delegate = self

            self.dataSource = .init( collectionView: self.collectionView ) { [unowned self] collectionView, indexPath, item in
                using( C.dequeue( from: collectionView, indexPath: indexPath ) ) {
                    self.pickerItem?.populate( $0, indexPath: indexPath, value: item )
                }
            }

            Task { await self.updateDataSource() }
        }

        func updateDataSource() async {
            if let pickerItem = self.pickerItem, let model = pickerItem.model {
                let values = await pickerItem.values( model )
                let sections = values.split( separator: nil ).map { $0.compactMap { $0 } }
                let selection = await pickerItem.valueProvider( model )
                self.dataSource?.apply( Dictionary( enumerated: sections ) ) {
                    self.dataSource?.select( item: selection, delegation: false )
                }
            }
        }

        override func doUpdate() async {
            await super.doUpdate()
            await self.updateDataSource()
        }

        // MARK: - UICollectionViewDelegate

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            Task {
                if let value = self.dataSource?.item( for: indexPath ), let pickerItem = self.pickerItem {
                    if let tracking = pickerItem.tracking( indexPath: indexPath, value: value ) {
                        Tracker.shared.event( track: tracking )
                    }

                    await pickerItem.update?( pickerItem, value )
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

    class PagerItemView: ValueItemView {
        let pagerView = PagerView()
        lazy var pageItems: [Item<M>] = [] {
            didSet {
                self.pageItems.forEach { $0.model = self.valueItem?.model }
                self.pagerView.pages = self.pageItems.map { $0.view }
                self.pageItems.forEach { $0.view.didLoad() }
                self.pageItems.forEach { $0.updateTask.request() }
            }
        }

        override func createValueView() -> UIView? {
            self.pagerView
        }

        override func doUpdate() async {
            await super.doUpdate()

            self.pageItems = await self.valueItem?.value ?? []
        }
    }
}

class ListItem<M, V: Hashable, C: UITableViewCell>: Item<M> {
    let values: (M) async -> [V]
    var deletable = false
    var animated  = true

    init(title: Message? = nil,
         values: @escaping (M) async -> [V],
         subitems: [Item<M>] = [], axis subitemAxis: NSLayoutConstraint.Axis = .horizontal,
         caption: @escaping (M) async -> Message? = { _ in nil }) {
        self.values = values

        super.init( title: title, subitems: subitems, axis: subitemAxis, caption: caption )
    }

    func populate(_ cell: C, indexPath: IndexPath, value: V) {
    }

    func delete(value: V) {
    }

    override func createItemView() -> ListItemView {
        ListItemView( withItem: self )
    }

    class ListItemView: ItemView, UITableViewDelegate {
        var listItem:   ListItem? {
            self.item as? ListItem
        }
        let tableView         = TableView()
        let activityIndicator = UIActivityIndicatorView( style: .large )
        var dataSource: DataSource<Int, V>?

        override func createValueView() -> UIView? {
            self.tableView
        }

        override func didLoad() {
            super.didLoad()

            self.dataSource = .init( tableView: self.tableView ) { [weak self] tableView, indexPath, item in
                C.dequeue( from: tableView, indexPath: indexPath ) { (cell: C) in
                    self?.listItem?.populate( cell, indexPath: indexPath, value: item )
                }
            } editor: { [weak self] item in
                guard self?.listItem?.deletable ?? false
                else { return nil }

                return {
                    if $0 == .delete, self?.listItem?.deletable ?? false {
                        self?.listItem?.delete( value: item )
                    }
                }
            }

            self.tableView.register( C.self )
            self.tableView.delegate = self
            self.tableView.tableHeaderView = self.activityIndicator
            self.activityIndicator.startAnimating()
        }

        override func doUpdate() async {
            await super.doUpdate()

            if let listItem = self.listItem, let model = listItem.model {
                self.tableView.isHidden = false
                self.tableView.tableHeaderView = self.activityIndicator

                await self.dataSource?.apply( [ 0: listItem.values( model ) ], animatingDifferences: listItem.animated ) {
                    self.tableView.isHidden = self.dataSource?.isEmpty ?? true
                    self.tableView.tableHeaderView = nil
                }
            }
        }

        // MARK: - UITableViewDelegate

        // MARK: - Types

        class TableView: UITableView {

            // MARK: - State

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

            // MARK: - Life

            required init?(coder aDecoder: NSCoder) {
                fatalError( "init(coder:) is not supported for this class" )
            }

            init() {
                super.init( frame: .zero, style: .plain )
                self.backgroundColor = .clear
                self.separatorStyle = .none
                LeakRegistry.shared.register( self )
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
        weak var item: LinksItem?
        var link: Link? {
            didSet {
                self.button.setTitle( self.link?.title, for: .normal )
            }
        }

        private let button = UIButton()

        // MARK: - Life

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init( style: style, reuseIdentifier: reuseIdentifier )
            LeakRegistry.shared.register(self)

            // - View
            self.isOpaque = false
            self.backgroundColor = .clear

            self.button => \.titleLabel!.font => Theme.current.font.callout
            self.button => \.currentTitleColor => Theme.current.color.body
            self.button => \.currentTitleShadowColor => Theme.current.color.shadow
            self.button.titleLabel!.shadowOffset = CGSize( width: 0, height: 1 )
            self.button.action( for: .primaryActionTriggered ) { [unowned self] in
                if let url = self.link?.url {
                    self.item?.viewController?.present( SFSafariViewController( url: url ), animated: true )
                }
            }

            // - Hierarchy
            self.contentView.addSubview( self.button )

            // - Layout
            LayoutConfiguration( view: self.button )
                .constrain( as: .box ).activate()
        }
    }
}
