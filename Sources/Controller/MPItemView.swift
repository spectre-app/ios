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

    private let title:    String?
    private let subitems: [Item<M>]
    private (set) lazy var view = createItemView()
    private let updateGroup = DispatchGroup()

    init(title: String? = nil, subitems: [Item<M>] = [ Item<M> ]()) {
        self.title = title
        self.subitems = subitems
    }

    func createItemView() -> ItemView<M> {
        return ItemView<M>( withItem: self )
    }

    func setNeedsUpdate() {
        self.subitems.forEach { $0.setNeedsUpdate() }

        if self.updateGroup.wait( timeout: .now() ) == .success {
            DispatchQueue.main.async( group: self.updateGroup ) {
                self.doUpdate()
            }
        }
    }

    func doUpdate() {
        self.view.update()
    }

    class ItemView<M>: UIView {
        let titleLabel   = UILabel()
        let contentView  = UIStackView()
        let subitemsView = UIStackView()
        private let item: Item<M>

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        init(withItem item: Item<M>) {
            self.item = item
            super.init( frame: .zero )

            // - View
            self.contentView.axis = .vertical
            self.contentView.spacing = 8
            self.contentView.preservesSuperviewLayoutMargins = true

            self.titleLabel.textColor = MPTheme.global.color.body.get()
            self.titleLabel.textAlignment = .center
            self.titleLabel.font = MPTheme.global.font.headline.get()
            self.contentView.addArrangedSubview( self.titleLabel )

            if let valueView = createValueView() {
                self.contentView.addArrangedSubview( valueView )
            }

            self.subitemsView.axis = .horizontal
            self.subitemsView.distribution = .fillEqually
            self.subitemsView.spacing = 20
            self.subitemsView.preservesSuperviewLayoutMargins = true
            self.subitemsView.isLayoutMarginsRelativeArrangement = true

            // - Hierarchy
            self.addSubview( self.contentView )
            self.addSubview( self.subitemsView )

            // - Layout
            LayoutConfiguration( view: self.contentView )
                    .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                    .constrainTo { $1.bottomAnchor.constraint( equalTo: self.subitemsView.topAnchor ) }
                    .activate()

            LayoutConfiguration( view: self.subitemsView )
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                    .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                    .constrainTo { $1.heightAnchor.constraint( equalToConstant: 0 ).withPriority( .fittingSizeLevel ) }
                    .activate()
        }

        func createValueView() -> UIView? {
            return nil
        }

        func update() {
            self.titleLabel.text = self.item.title
            self.titleLabel.isHidden = self.item.title == nil

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
        return SeparatorItemView<M>( withItem: self )
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
            self.separatorView.backgroundColor = MPTheme.global.color.body.get()
            self.separatorView.heightAnchor.constraint( equalToConstant: 1 ).activate()
            return self.separatorView
        }
    }
}

class ValueItem<M, V>: Item<M> {
    let itemValue: (M) -> V?
    var value:     V? {
        get {
            if let model = self.model {
                return self.itemValue( model )
            }
            else {
                return nil
            }
        }
    }

    init(title: String? = nil, subitems: [Item<M>] = [ Item<M> ](), itemValue: @escaping (M) -> V? = { _ in nil }) {
        self.itemValue = itemValue
        super.init( title: title, subitems: subitems )
    }
}

class LabelItem<M>: ValueItem<M, (Any?, Any?)> {
    override func createItemView() -> LabelItemView<M> {
        return LabelItemView<M>( withItem: self )
    }

    class LabelItemView<M>: ItemView<M> {
        let item: LabelItem
        let primaryLabel   = UILabel()
        let secondaryLabel = UILabel()

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item<M>) {
            self.item = item as! LabelItem
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.primaryLabel.font = MPTheme.global.font.largeTitle.get()
            self.primaryLabel.textAlignment = .center
            self.primaryLabel.textColor = MPTheme.global.color.body.get()
            self.primaryLabel.shadowColor = MPTheme.global.color.shadow.get()
            self.primaryLabel.shadowOffset = CGSize( width: 0, height: 1 )

            self.secondaryLabel.font = MPTheme.global.font.caption1.get()
            self.secondaryLabel.textAlignment = .center
            self.secondaryLabel.textColor = MPTheme.global.color.secondary.get()
            self.secondaryLabel.shadowColor = MPTheme.global.color.shadow.get()
            self.secondaryLabel.shadowOffset = CGSize( width: 0, height: 1 )

            let valueView = UIStackView( arrangedSubviews: [ self.primaryLabel, self.secondaryLabel ] )
            valueView.axis = .vertical
            return valueView
        }

        override func update() {
            super.update()

            if let primary = self.item.value?.0 {
                if let primary = primary as? NSAttributedString {
                    self.primaryLabel.attributedText = primary
                }
                else {
                    self.primaryLabel.text = String( describing: primary )
                }
                self.primaryLabel.isHidden = false
            }
            else {
                self.primaryLabel.isHidden = true
            }
            if let secondary = self.item.value?.1 {
                if let secondary = secondary as? NSAttributedString {
                    self.secondaryLabel.attributedText = secondary
                }
                else {
                    self.secondaryLabel.text = String( describing: secondary )
                }
                self.secondaryLabel.isHidden = false
            }
            else {
                self.secondaryLabel.isHidden = true
            }
        }
    }
}

class ButtonItem<M>: ValueItem<M, (String?, UIImage?)> {
    let itemAction: (ButtonItem<M>) -> Void

    init(title: String? = nil, subitems: [Item<M>] = [],
         itemValue: @escaping (M) -> (String?, UIImage?),
         itemAction: @escaping (ButtonItem<M>) -> Void = { _ in }) {
        self.itemAction = itemAction

        super.init( title: title, subitems: subitems, itemValue: itemValue )
    }

    override func createItemView() -> ButtonItemView<M> {
        return ButtonItemView<M>( withItem: self )
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
//            self.button.textColor = MPTheme.global.color.body.get()
//            self.button.textAlignment = .center
//            self.button.font = MPTheme.global.font.largeTitle.get()
            self.button.button.addAction( for: .touchUpInside ) { _, _ in
                self.item.itemAction( self.item )
            }
            return self.button
        }

        override func update() {
            super.update()

            self.button.title = self.item.value?.0
            self.button.image = self.item.value?.1
        }
    }
}

class DateItem<M>: ValueItem<M, Date> {
    override func createItemView() -> DateItemView<M> {
        return DateItemView<M>( withItem: self )
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

class TextItem<M>: ValueItem<M, String>, UITextFieldDelegate {
    let placeholder: String?
    let itemUpdate:  (M, String) -> Void

    init(title: String?, placeholder: String?, subitems: [Item<M>] = [],
         itemValue: @escaping (M) -> String? = { _ in nil },
         itemUpdate: @escaping (M, String) -> Void = { _, _ in }) {
        self.placeholder = placeholder
        self.itemUpdate = itemUpdate
        super.init( title: title, subitems: subitems, itemValue: itemValue )
    }

    override func createItemView() -> TextItemView<M> {
        return TextItemView<M>( withItem: self )
    }

    // MARK: UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing( false )
        return true
    }

    class TextItemView<M>: ItemView<M> {
        let item: TextItem
        let valueField = UITextField()

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item<M>) {
            self.item = item as! TextItem
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.valueField.delegate = self.item
            self.valueField.textColor = MPTheme.global.color.body.get()
            self.valueField.textAlignment = .center
            self.valueField.addAction( for: .editingChanged ) { _, _ in
                if let model = self.item.model,
                   let text = self.valueField.text {
                    self.item.itemUpdate( model, text )
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

class StepperItem<M, V: AdditiveArithmetic & Comparable>: ValueItem<M, V> {
    let itemUpdate: (M, V) -> Void
    let step:       V, min: V, max: V

    init(title: String? = nil, subitems: [Item<M>] = [],
         itemValue: @escaping (M) -> V? = { _ in nil },
         itemUpdate: @escaping (M, V) -> Void = { _, _ in },
         step: V, min: V, max: V) {
        self.itemUpdate = itemUpdate
        self.step = step
        self.min = min
        self.max = max
        super.init( title: title, subitems: subitems, itemValue: itemValue )
    }

    override func createItemView() -> StepperItemView<M> {
        return StepperItemView<M>( withItem: self )
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
            self.downButton.effectBackground = false
            self.downButton.button.addAction( for: .touchUpInside ) { _, _ in
                if let model = self.item.model,
                   let value = self.item.value,
                   value > self.item.min {
                    self.item.itemUpdate( model, value - self.item.step )
                }
            }

            self.upButton.effectBackground = false
            self.upButton.button.addAction( for: .touchUpInside ) { _, _ in
                if let model = self.item.model,
                   let value = self.item.value,
                   value < self.item.max {
                    self.item.itemUpdate( model, value + self.item.step )
                }
            }

            self.valueLabel.font = MPTheme.global.font.largeTitle.get()
            self.valueLabel.textAlignment = .center
            self.valueLabel.textColor = MPTheme.global.color.body.get()
            self.valueLabel.shadowColor = MPTheme.global.color.shadow.get()
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

class PickerItem<M, V: Equatable>: ValueItem<M, V> {
    let values:     [V]
    let itemUpdate: (M, V) -> Void
    let itemCell:   (UICollectionView, IndexPath, V) -> UICollectionViewCell
    let viewInit:   (UICollectionView) -> Void

    init(title: String?, values: [V], subitems: [Item<M>] = [],
         itemValue: @escaping (M) -> V,
         itemUpdate: @escaping (M, V) -> Void = { _, _ in },
         itemCell: @escaping (UICollectionView, IndexPath, V) -> UICollectionViewCell,
         viewInit: @escaping (UICollectionView) -> Void) {
        self.values = values
        self.itemUpdate = itemUpdate
        self.itemCell = itemCell
        self.viewInit = viewInit

        super.init( title: title, subitems: subitems, itemValue: itemValue )
    }

    override func createItemView() -> PickerItemView<M> {
        return PickerItemView<M>( withItem: self )
    }

    class PickerItemView<M>: ItemView<M>, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
        let item: PickerItem<M, V>
        let collectionView = CollectionView()

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
            self.item.viewInit( self.collectionView )
            return self.collectionView
        }

        override func update() {
            super.update()

            // TODO: reload items non-destructively
            //self.collectionView.reloadData()
            self.updateSelection()
        }

        // MARK: --- Private ---

        private func updateSelection() {
            if let model = self.item.model,
               let selectedValue = self.item.itemValue( model ),
               let selectedIndex = self.item.values.firstIndex( of: selectedValue ),
               let selectedIndexPaths = self.collectionView.indexPathsForSelectedItems {
                let selectedIndexPath = IndexPath( item: selectedIndex, section: 0 )
                if !selectedIndexPaths.elementsEqual( [ selectedIndexPath ] ) {
                    if self.collectionView.visibleCells.count > 0 {
                        self.collectionView.selectItem( at: selectedIndexPath, animated: false, scrollPosition: .centeredHorizontally )
                    }
                    else {
                        DispatchQueue.main.async {
                            if self.window != nil {
                                self.updateSelection()
                            }
                        }
                    }
                }
            }
        }

        // MARK: --- UICollectionViewDataSource ---

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            return self.item.values.count
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            return self.item.itemCell( collectionView, indexPath, self.item.values[indexPath.item] )
        }

        // MARK: --- UICollectionViewDelegateFlowLayout ---

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            if let model = self.item.model {
                self.item.itemUpdate( model, self.item.values[indexPath.item] )
            }
        }

        func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        }

        class CollectionView: UICollectionView {
            let layout = CollectionViewFlowLayout()

            required init?(coder aDecoder: NSCoder) {
                fatalError( "init(coder:) is not supported for this class" )
            }

            init() {
                super.init( frame: .zero, collectionViewLayout: self.layout )
                self.backgroundColor = .clear
            }

            override var intrinsicContentSize: CGSize {
                var contentSize = self.collectionViewLayout.collectionViewContentSize, itemSize = self.layout.itemSize
                if let cell = self.visibleCells.first {
                    itemSize = cell.systemLayoutSizeFitting( contentSize )
                }
                else if self.numberOfSections > 0, self.numberOfItems( inSection: 0 ) > 0 {
                    let first = IndexPath( item: 0, section: 0 )
                    if let size = (self.delegate as? UICollectionViewDelegateFlowLayout)?
                            .collectionView?( self, layout: self.layout, sizeForItemAt: first ) {
                        itemSize = size
                    }
                    else if let cell = self.dataSource?.collectionView( self, cellForItemAt: first ) {
                        itemSize = cell.systemLayoutSizeFitting( contentSize )
                    }
                }
                itemSize.width += self.layout.sectionInset.left + self.layout.sectionInset.right
                itemSize.height += self.layout.sectionInset.top + self.layout.sectionInset.bottom
                contentSize = CGSizeUnion( contentSize, itemSize )

                return contentSize
            }

            class CollectionViewFlowLayout: UICollectionViewFlowLayout {
                required init?(coder aDecoder: NSCoder) {
                    fatalError( "init(coder:) is not supported for this class" )
                }

                override init() {
                    super.init()

                    self.scrollDirection = .horizontal
                    self.sectionInset = UIEdgeInsets( top: 0, left: 20, bottom: 0, right: 20 )
                    self.minimumInteritemSpacing = 12
                    self.minimumLineSpacing = 12

                    if #available( iOS 10.0, * ) {
                        self.estimatedItemSize = UICollectionViewFlowLayoutAutomaticSize
                    }
                    else {
                        self.estimatedItemSize = self.itemSize
                    }
                }

                override func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {
                    super.invalidateLayout( with: context )
                    self.collectionView?.invalidateIntrinsicContentSize()
                }
            }
        }
    }
}
