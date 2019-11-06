//
// Created by Maarten Billemont on 2019-04-26.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class Item<M>: NSObject {
    public var viewController: UIViewController? {
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

    private let title:          String?
    private let captionFactory: (M) -> CustomStringConvertible?
    private let hiddenFactory:  (M) -> Bool
    private let subitems:       [Item<M>]
    private (set) lazy var view = createItemView()

    private lazy var updateTask = DispatchTask( queue: DispatchQueue.main, qos: .userInitiated, deadline: .now() + .milliseconds( 100 ) ) {
        UIView.animate( withDuration: 0.382 ) {
            self.doUpdate()
        }
    }

    init(title: String? = nil, subitems: [Item<M>] = [ Item<M> ](),
         caption captionFactory: @escaping (M) -> CustomStringConvertible? = { _ in nil },
         hidden hiddenFactory: @escaping (M) -> Bool = { _ in false }) {
        self.title = title
        self.subitems = subitems
        self.captionFactory = captionFactory
        self.hiddenFactory = hiddenFactory
    }

    func createItemView() -> ItemView<M> {
        ItemView<M>( withItem: self )
    }

    func setNeedsUpdate() {
        guard self.viewController != nil
        else { return }

        self.subitems.forEach { $0.setNeedsUpdate() }
        self.updateTask.request()
    }

    func doUpdate() {
        self.subitems.forEach { $0.doUpdate() }
        self.view.update()
    }

    class ItemView<M>: UIView {
        let titleLabel   = UILabel()
        let captionLabel = UILabel()
        let contentView  = UIStackView()
        let subitemsView = UIStackView()

        private lazy var valueView = self.createValueView()
        private let item: Item<M>

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
            self.titleLabel.textColor = appConfig.theme.color.body.get()
            self.titleLabel.textAlignment = .center
            self.titleLabel.font = appConfig.theme.font.headline.get()
            self.titleLabel.setContentHuggingPriority( .defaultHigh, for: .vertical )
            self.titleLabel.setAlignmentRectOutsets( UIEdgeInsets( top: 0, left: 8, bottom: 0, right: 8 ) )

            self.subitemsView.axis = .horizontal
            self.subitemsView.distribution = .fillEqually
            self.subitemsView.alignment = .firstBaseline
            self.subitemsView.spacing = 20
            self.subitemsView.preservesSuperviewLayoutMargins = true
            self.subitemsView.isLayoutMarginsRelativeArrangement = true

            self.captionLabel.textColor = appConfig.theme.color.secondary.get()
            self.captionLabel.textAlignment = .center
            self.captionLabel.font = appConfig.theme.font.caption1.get()
            self.captionLabel.numberOfLines = 0
            self.captionLabel.setContentHuggingPriority( .defaultHigh, for: .vertical )
            self.captionLabel.setAlignmentRectOutsets( UIEdgeInsets( top: 0, left: 8, bottom: 0, right: 8 ) )

            // - Hierarchy
            self.addSubview( self.contentView )
            self.contentView.addArrangedSubview( self.titleLabel )
            if let valueView = self.valueView {
                self.contentView.addArrangedSubview( valueView )
            }
            self.contentView.addArrangedSubview( self.subitemsView )
            self.contentView.addArrangedSubview( self.captionLabel )

            // - Layout
            LayoutConfiguration( view: self.contentView )
                    .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                    .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                    .activate()

            LayoutConfiguration( view: self.subitemsView )
                    .constrainTo { $1.widthAnchor.constraint( equalTo: $0.widthAnchor ).withPriority( .defaultHigh ) }
                    .constrainTo { $1.heightAnchor.constraint( equalToConstant: 0 ).withPriority( .fittingSizeLevel ) }
                    .activate()
        }

        func createValueView() -> UIView? {
            nil
        }

        func didLoad() {
            if let valueView = self.valueView {
                valueView.superview?.readableContentGuide.widthAnchor.constraint( equalTo: valueView.widthAnchor )
                                                                     .withPriority( .defaultLow + 1 ).activate()
            }
        }

        func update() {
            self.isHidden = self.item.model.flatMap { self.item.hiddenFactory( $0 ) } ?? true

            self.titleLabel.text = self.item.title
            self.titleLabel.isHidden = self.item.title == nil

            self.captionLabel.text = self.item.model.flatMap { self.item.captionFactory( $0 )?.description }
            self.captionLabel.isHidden = self.captionLabel.text == nil

            for i in 0..<max( self.item.subitems.count, self.subitemsView.arrangedSubviews.count ) {
                let subitemView     = i < self.item.subitems.count ? self.item.subitems[i].view: nil
                let arrangedSubview = i < self.subitemsView.arrangedSubviews.count ? self.subitemsView.arrangedSubviews[i]: nil

                if arrangedSubview != subitemView {
                    arrangedSubview?.removeFromSuperview()

                    if let subitemView = subitemView {
                        self.subitemsView.insertArrangedSubview( subitemView, at: i )
                    }
                }
            }
            self.subitemsView.isHidden = self.subitemsView.arrangedSubviews.count == 0
        }
    }
}

class SeparatorItem<M>: Item<M> {
    override func createItemView() -> ItemView<M> {
        SeparatorItemView<M>( withItem: self )
    }

    class SeparatorItemView<M>: ItemView<M> {
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
            self.separatorView.backgroundColor = appConfig.theme.color.mute.get()
            self.separatorView.heightAnchor.constraint( equalToConstant: 1 ).activate()
            return self.separatorView
        }
    }
}

class ValueItem<M, V>: Item<M> {
    let valueFactory: (M) -> V?
    var value: V? {
        self.model.flatMap { self.valueFactory( $0 ) }
    }

    init(title: String? = nil, subitems: [Item<M>] = [ Item<M> ](),
         value valueFactory: @escaping (M) -> V? = { _ in nil },
         caption: @escaping (M) -> CustomStringConvertible? = { _ in nil },
         hidden: @escaping (M) -> Bool = { _ in false }) {
        self.valueFactory = valueFactory
        super.init( title: title, subitems: subitems, caption: caption, hidden: hidden )
    }
}

class LabelItem<M>: ValueItem<M, Any> {
    override func createItemView() -> LabelItemView<M> {
        LabelItemView<M>( withItem: self )
    }

    class LabelItemView<M>: ItemView<M> {
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
            self.valueLabel.font = appConfig.theme.font.largeTitle.get()
            self.valueLabel.textAlignment = .center
            self.valueLabel.textColor = appConfig.theme.color.body.get()
            self.valueLabel.shadowColor = appConfig.theme.color.shadow.get()
            self.valueLabel.shadowOffset = CGSize( width: 0, height: 1 )

            return self.valueLabel
        }

        override func update() {
            super.update()

            if let value = self.item.value as? NSAttributedString {
                self.valueLabel.attributedText = value
                self.valueLabel.isHidden = false
            }
            else if let value = self.item.value {
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

class ToggleItem<M>: ValueItem<M, (icon: UIImage?, selected: Bool, enabled: Bool)> {
    let update: (M, Bool) -> Void

    init(title: String? = nil, subitems: [Item<M>] = [],
         value: @escaping (M) -> (icon: UIImage?, selected: Bool, enabled: Bool),
         update: @escaping (M, Bool) -> Void = { _, _ in },
         caption: @escaping (M) -> CustomStringConvertible? = { _ in nil },
         hidden: @escaping (M) -> Bool = { _ in false }) {
        self.update = update

        super.init( title: title, subitems: subitems, value: value, caption: caption, hidden: hidden )
    }

    override func createItemView() -> ToggleItemView<M> {
        ToggleItemView<M>( withItem: self )
    }

    class ToggleItemView<M>: ItemView<M> {
        let item: ToggleItem
        let button = MPToggleButton()

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item<M>) {
            self.item = item as! ToggleItem
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.button.addAction( for: .touchUpInside ) { [unowned self] _, _ in
                if let model = self.item.model {
                    self.button.isSelected = !self.button.isSelected
                    self.item.update( model, self.button.isSelected )
                    self.item.setNeedsUpdate()
                }
            }
            return self.button
        }

        override func update() {
            super.update()

            self.button.setImage( self.item.value?.icon, for: .normal )
            self.button.isSelected = self.item.value?.selected ?? false
            self.button.isEnabled = self.item.value?.enabled ?? false
        }
    }
}

class ButtonItem<M>: ValueItem<M, (label: String?, image: UIImage?)> {
    let action: (ButtonItem<M>) -> Void

    init(title: String? = nil, subitems: [Item<M>] = [],
         value: @escaping (M) -> (label: String?, image: UIImage?),
         caption: @escaping (M) -> CustomStringConvertible? = { _ in nil },
         hidden: @escaping (M) -> Bool = { _ in false },
         action: @escaping (ButtonItem<M>) -> Void = { _ in }) {
        self.action = action

        super.init( title: title, subitems: subitems, value: value, caption: caption, hidden: hidden )
    }

    override func createItemView() -> ButtonItemView<M> {
        ButtonItemView<M>( withItem: self )
    }

    class ButtonItemView<M>: ItemView<M> {
        let item: ButtonItem
        let button = MPButton()

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item<M>) {
            self.item = item as! ButtonItem
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.button.button.addAction( for: .touchUpInside ) { [unowned self] _, _ in
                self.item.action( self.item )
            }
            return self.button
        }

        override func update() {
            super.update()

            self.button.title = self.item.value?.label
            self.button.image = self.item.value?.image
        }
    }
}

class DateItem<M>: ValueItem<M, Date> {
    override func createItemView() -> DateItemView<M> {
        DateItemView<M>( withItem: self )
    }

    class DateItemView<M>: ItemView<M> {
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
         caption: @escaping (M) -> CustomStringConvertible? = { _ in nil },
         hidden: @escaping (M) -> Bool = { _ in false }) {
        self.placeholder = placeholder
        self.update = update
        super.init( title: title, subitems: subitems, value: value, caption: caption, hidden: hidden )
    }

    override func createItemView() -> FieldItemView<M> {
        FieldItemView<M>( withItem: self )
    }

    // MARK: UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing( false )
        return true
    }

    class FieldItemView<M>: ItemView<M> {
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
            self.valueField.textColor = appConfig.theme.color.body.get()
            self.valueField.textAlignment = .center
            self.valueField.addAction( for: .editingChanged ) { [unowned self] _, _ in
                if let model = self.item.model,
                   let text = self.valueField.text {
                    self.item.update?( model, text )
                }
            }
            return self.valueField
        }

        override func update() {
            super.update()

            self.valueField.isEnabled = self.item.update != nil
            self.valueField.placeholder = self.item.placeholder
            self.valueField.text = self.item.value
        }
    }
}

class AreaItem<M>: ValueItem<M, String>, UITextViewDelegate {
    let update: ((M, String) -> Void)?

    init(title: String? = nil, subitems: [Item<M>] = [],
         value: @escaping (M) -> String? = { _ in nil },
         update: ((M, String) -> Void)? = nil,
         caption: @escaping (M) -> CustomStringConvertible? = { _ in nil },
         hidden: @escaping (M) -> Bool = { _ in false }) {
        self.update = update
        super.init( title: title, subitems: subitems, value: value, caption: caption, hidden: hidden )
    }

    override func createItemView() -> AreaItemView<M> {
        AreaItemView<M>( withItem: self )
    }

    // MARK: UITextViewDelegate

    func textViewDidChange(_ textView: UITextView) {
        if let model = self.model, let text = textView.text {
            self.update?( model, text )
        }
    }

    class AreaItemView<M>: ItemView<M> {
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
            self.valueView.font = appConfig.theme.font.mono.get()?.withSize( 11 )
            self.valueView.textColor = appConfig.theme.color.body.get()
            self.valueView.backgroundColor = .clear
            return self.valueView
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()

            if let window = self.valueView.window {
                self.valueView.heightAnchor.constraint( equalTo: window.heightAnchor, multiplier: 0.618 )
                                           .withPriority( .defaultHigh ).activate()
            }
        }

        override func update() {
            super.update()

            self.valueView.isEditable = self.item.update != nil
            self.valueView.text = self.item.value
        }
    }
}

class StepperItem<M, V: AdditiveArithmetic & Comparable>: ValueItem<M, V> {
    let update: (M, V) -> Void
    let step:   V, min: V, max: V

    init(title: String? = nil, subitems: [Item<M>] = [],
         value: @escaping (M) -> V? = { _ in nil },
         update: @escaping (M, V) -> Void = { _, _ in },
         step: V, min: V, max: V,
         caption: @escaping (M) -> CustomStringConvertible? = { _ in nil },
         hidden: @escaping (M) -> Bool = { _ in false }) {
        self.update = update
        self.step = step
        self.min = min
        self.max = max
        super.init( title: title, subitems: subitems, value: value, caption: caption, hidden: hidden )
    }

    override func createItemView() -> StepperItemView<M> {
        StepperItemView<M>( withItem: self )
    }

    class StepperItemView<M>: ItemView<M> {
        let item: StepperItem
        let valueView  = UIView()
        let valueLabel = UILabel()
        let downButton = MPButton( title: "-" )
        let upButton   = MPButton( title: "+" )

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item<M>) {
            self.item = item as! StepperItem
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.downButton.isBackgroundVisible = false
            self.downButton.button.addAction( for: .touchUpInside ) { [unowned self] _, _ in
                if let model = self.item.model,
                   let value = self.item.value,
                   value > self.item.min {
                    self.item.update( model, value - self.item.step )
                }
            }

            self.upButton.isBackgroundVisible = false
            self.upButton.button.addAction( for: .touchUpInside ) { [unowned self] _, _ in
                if let model = self.item.model,
                   let value = self.item.value,
                   value < self.item.max {
                    self.item.update( model, value + self.item.step )
                }
            }

            self.valueLabel.font = appConfig.theme.font.largeTitle.get()
            self.valueLabel.textAlignment = .center
            self.valueLabel.textColor = appConfig.theme.color.body.get()
            self.valueLabel.shadowColor = appConfig.theme.color.shadow.get()
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

            if let value = self.item.value {
                self.valueLabel.text = "\(value)"
            }
            else {
                self.valueLabel.text = nil
            }
        }
    }
}

class PickerItem<M, V: Hashable>: ValueItem<M, V> {
    let values: (M) -> [V]
    let update: (M, V) -> Void

    init(title: String? = nil, values: @escaping (M) -> [V], subitems: [Item<M>] = [],
         value: @escaping (M) -> V, update: @escaping (M, V) -> Void = { _, _ in },
         caption: @escaping (M) -> CustomStringConvertible? = { _ in nil },
         hidden: @escaping (M) -> Bool = { _ in false }) {
        self.values = values
        self.update = update

        super.init( title: title, subitems: subitems, value: value, caption: caption, hidden: hidden )
    }

    override func createItemView() -> PickerItemView<M> {
        PickerItemView<M>( withItem: self )
    }

    func didLoad(collectionView: UICollectionView) {
    }

    func cell(collectionView: UICollectionView, indexPath: IndexPath, model: M, value: V) -> UICollectionViewCell? {
        nil
    }

    class PickerItemView<M>: ItemView<M>, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
        let item: PickerItem<M, V>
        let collectionView = PickerView()
        lazy var dataSource = DataSource<V>( collectionView: self.collectionView )

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item<M>) {
            self.item = item as! PickerItem<M, V>
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.collectionView.delegate = self
            self.collectionView.dataSource = self
            return self.collectionView
        }

        override func didLoad() {
            super.didLoad()

            self.item.didLoad( collectionView: self.collectionView )
        }

        override func update() {
            super.update()

            self.dataSource.update( [ self.item.model.flatMap { self.item.values( $0 ) } ?? [] ] )
            self.updateSelection()
        }

        // MARK: --- Private ---

        private func updateSelection() {
            if let model = self.item.model,
               let selectedValue = self.item.valueFactory( model ),
               let selectedIndexPath = self.dataSource.indexPath( for: selectedValue ),
               let selectedIndexPaths = self.collectionView.indexPathsForSelectedItems,
               selectedIndexPaths != [ selectedIndexPath ] {
                self.collectionView.selectItem( at: selectedIndexPath, animated: UIView.areAnimationsEnabled, scrollPosition: .centeredHorizontally )
            }
        }

        // MARK: --- UICollectionViewDataSource ---

        func numberOfSections(in collectionView: UICollectionView) -> Int {
            self.dataSource.numberOfSections
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            self.dataSource.numberOfItems( in: section )
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            self.item.cell( collectionView: collectionView, indexPath: indexPath,
                            model: self.item.model!, value: self.dataSource.element( at: indexPath )! )!
        }

        // MARK: --- UICollectionViewDelegateFlowLayout ---

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            if let model = self.item.model, let value = self.dataSource.element( at: indexPath ) {
                self.item.update( model, value )
            }
        }

        func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        }

        class PickerView: UICollectionView {
            let layout = PickerLayout()

            required init?(coder aDecoder: NSCoder) {
                fatalError( "init(coder:) is not supported for this class" )
            }

            init() {
                super.init( frame: UIScreen.main.bounds, collectionViewLayout: self.layout )
                self.backgroundColor = .clear
            }

            override var intrinsicContentSize: CGSize {
                if self.numberOfSections > 0 && self.numberOfItems( inSection: 0 ) > 0,
                   let itemSize = self.layout.layoutAttributesForItem( at: IndexPath( item: 0, section: 0 ) )?.size {
                    return itemSize + self.layoutMargins.size
                }

                return CGSize( width: 1, height: 1 ) + self.layoutMargins.size
            }

            class PickerLayout: UICollectionViewLayout {
                private var itemAttributes = [ IndexPath: UICollectionViewLayoutAttributes ]()
                private let initialSize    = CGSize( width: 50, height: 50 )
                private var contentSize    = CGSize.zero
                private let spacing        = CGFloat( 12 )

                open override var collectionViewContentSize: CGSize {
                    self.contentSize
                }

                open override func prepare() {
                    super.prepare()

                    let oldAttributes = self.itemAttributes
                    let start         = self.collectionView?.layoutMargins.left ?? 0
                    var offset        = start, height = CGFloat( 0 )

                    self.itemAttributes.removeAll()
                    for section in 0..<(self.collectionView?.numberOfSections ?? 0) {
                        for item in 0..<(self.collectionView?.numberOfItems( inSection: section ) ?? 0) {
                            let path = IndexPath( item: item, section: section )
                            let attr = oldAttributes[path] ?? UICollectionViewLayoutAttributes( forCellWith: path )
                            if attr.size == .zero {
                                attr.size = self.initialSize
                            }

                            attr.frame.origin = CGPoint( x: offset == start ? start: offset + spacing,
                                                         y: self.collectionView?.layoutMargins.top ?? 0 )
                            height = max( height, attr.frame.maxY )
                            offset = attr.frame.maxX

                            self.itemAttributes[path] = attr
                        }
                    }

                    self.contentSize = CGSize( width: offset + (self.collectionView?.layoutMargins.right ?? 0),
                                               height: height + (self.collectionView?.layoutMargins.bottom ?? 0) )
                    self.collectionView?.invalidateIntrinsicContentSize()
                }

                open override func shouldInvalidateLayout(forPreferredLayoutAttributes preferredAttributes: UICollectionViewLayoutAttributes,
                                                          withOriginalAttributes originalAttributes: UICollectionViewLayoutAttributes) -> Bool {
                    if let currentAttributes = self.itemAttributes[originalAttributes.indexPath],
                       currentAttributes.size != preferredAttributes.size {
                        currentAttributes.size = preferredAttributes.size
                        return true
                    }

                    return false
                }

                open override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
                    self.itemAttributes.values.filter { rect.intersects( $0.frame ) }
                }

                open override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
                    self.itemAttributes[indexPath]
                }

                open override func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
                    self.itemAttributes[itemIndexPath]
                }
            }
        }
    }
}

class ListItem<M, V: Hashable>: Item<M> {
    let values: (M) -> [V]
    var deletable = false

    init(title: String? = nil, values: @escaping (M) -> [V], subitems: [Item<M>] = [],
         caption: @escaping (M) -> CustomStringConvertible? = { _ in nil },
         hidden: @escaping (M) -> Bool = { _ in false }) {
        self.values = values

        super.init( title: title, subitems: subitems, caption: caption, hidden: hidden )
    }

    func didLoad(tableView: UITableView) {
    }

    func cell(tableView: UITableView, indexPath: IndexPath, model: M, value: V) -> UITableViewCell? {
        nil
    }

    func delete(model: M, value: V) {
    }

    override func createItemView() -> ListItemView<M> {
        ListItemView<M>( withItem: self )
    }

    class ListItemView<M>: ItemView<M>, UITableViewDelegate, UITableViewDataSource {
        let item: ListItem<M, V>
        let tableView = TableView()
        lazy var dataSource = DataSource<V>( tableView: self.tableView )

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item<M>) {
            self.item = item as! ListItem<M, V>
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.tableView.delegate = self
            self.tableView.dataSource = self
            return self.tableView
        }

        override func didLoad() {
            super.didLoad()

            self.item.didLoad( tableView: self.tableView )
        }

        override func update() {
            super.update()

            self.dataSource.update( [ self.item.model.flatMap { self.item.values( $0 ) } ?? [] ] )
        }

        // MARK: --- UITableViewDataSource ---

        func numberOfSections(in tableView: UITableView) -> Int {
            self.dataSource.numberOfSections
        }

        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            self.dataSource.numberOfItems( in: section )
        }

        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            self.item.cell( tableView: tableView, indexPath: indexPath,
                            model: self.item.model!, value: self.dataSource.element( at: indexPath )! )!
        }

        func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
            self.item.deletable
        }

        func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
            if editingStyle == .delete, self.item.deletable,
               let model = self.item.model, let value = self.dataSource.element( at: indexPath ) {
                self.item.delete( model: model, value: value )
            }
        }

        // MARK: --- UITableViewDelegate ---

        class TableView: PearlFixedTableView {
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
