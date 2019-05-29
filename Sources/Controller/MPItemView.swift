//
// Created by Maarten Billemont on 2019-04-26.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class Item: MPSiteObserver {
    public var site: MPSite? {
        willSet {
            self.site?.observers.unregister( self )
        }
        didSet {
            if let site = self.site {
                site.observers.register( self ).siteDidChange( site )
            }

            ({
                 for subitem in self.subitems {
                     subitem.site = self.site
                 }
             }()) // this is a hack to get around Swift silently skipping recursive didSet on properties.
        }
    }

    private let title:    String?
    private let subitems: [Item]
    private (set) lazy var view = createItemView()
    private let updateGroup = DispatchGroup()

    init(title: String? = nil, subitems: [Item] = [ Item ]()) {
        self.title = title
        self.subitems = subitems
    }

    func createItemView() -> ItemView {
        return ItemView( withItem: self )
    }

    func siteDidChange(_ site: MPSite) {
        self.setNeedsUpdate()
    }

    func setNeedsUpdate() {
        if self.updateGroup.wait( timeout: .now() ) == .success {
            DispatchQueue.main.perform( group: self.updateGroup ) {
                self.view.update()
            }
        }
    }

    class ItemView: UIView {
        let titleLabel   = UILabel()
        let contentView  = UIStackView()
        let subitemsView = UIStackView()
        private let item: Item

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        init(withItem item: Item) {
            self.item = item
            super.init( frame: .zero )

            // - View
            self.contentView.axis = .vertical
            self.contentView.spacing = 8
            self.contentView.preservesSuperviewLayoutMargins = true

            self.titleLabel.textColor = .white
            self.titleLabel.textAlignment = .center
            self.titleLabel.font = UIFont.preferredFont( forTextStyle: .headline )
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
            ViewConfiguration( view: self.contentView )
                    .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                    .constrainTo { $1.bottomAnchor.constraint( equalTo: self.subitemsView.topAnchor ) }
                    .activate()
            ViewConfiguration( view: self.subitemsView )
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

class SeparatorItem: Item {
    override func createItemView() -> ItemView {
        return SeparatorItemView( withItem: self )
    }

    class SeparatorItemView: ItemView {
        let item: SeparatorItem
        let separatorView = UIView()

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item) {
            self.item = item as! SeparatorItem
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.separatorView.backgroundColor = .white
            self.separatorView.heightAnchor.constraint( equalToConstant: 1 ).activate()
            return self.separatorView
        }
    }
}

class ValueItem<V>: Item {
    let itemValue: (MPSite) -> V?
    var value:     V? {
        get {
            if let site = self.site {
                return self.itemValue( site )
            }
            else {
                return nil
            }
        }
    }

    init(title: String? = nil, subitems: [Item] = [ Item ](), itemValue: @escaping (MPSite) -> V? = { _ in nil }) {
        self.itemValue = itemValue
        super.init( title: title, subitems: subitems )
    }
}

class LabelItem: ValueItem<String> {
    override func createItemView() -> LabelItemView {
        return LabelItemView( withItem: self )
    }

    class LabelItemView: ItemView {
        let item: LabelItem
        let valueLabel = UILabel()

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item) {
            self.item = item as! LabelItem
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.valueLabel.textColor = .white
            self.valueLabel.textAlignment = .center
            if #available( iOS 11.0, * ) {
                self.valueLabel.font = UIFont.preferredFont( forTextStyle: .largeTitle )
            }
            else {
                self.valueLabel.font = UIFont.preferredFont( forTextStyle: .title1 ).withSymbolicTraits( .traitBold )
            }
            return self.valueLabel
        }

        override func update() {
            super.update()

            self.valueLabel.text = self.item.value
        }
    }
}

class SubLabelItem: ValueItem<(String, String)> {
    override func createItemView() -> SubLabelItemView {
        return SubLabelItemView( withItem: self )
    }

    class SubLabelItemView: ItemView {
        let item: SubLabelItem
        let primaryLabel   = UILabel()
        let secondaryLabel = UILabel()

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item) {
            self.item = item as! SubLabelItem
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.primaryLabel.textColor = .white
            self.primaryLabel.textAlignment = .center
            if #available( iOS 11.0, * ) {
                self.primaryLabel.font = UIFont.preferredFont( forTextStyle: .largeTitle )
            }
            else {
                self.primaryLabel.font = UIFont.preferredFont( forTextStyle: .title1 ).withSymbolicTraits( .traitBold )
            }

            self.secondaryLabel.textColor = .white
            self.secondaryLabel.textAlignment = .center
            self.secondaryLabel.font = UIFont.preferredFont( forTextStyle: .caption1 )

            let valueView = UIStackView( arrangedSubviews: [ self.primaryLabel, self.secondaryLabel ] )
            valueView.axis = .vertical
            return valueView
        }

        override func update() {
            super.update()

            self.primaryLabel.text = self.item.value?.0
            self.secondaryLabel.text = self.item.value?.1
        }
    }
}

class DateItem: ValueItem<Date> {
    override func createItemView() -> DateItemView {
        return DateItemView( withItem: self )
    }

    class DateItemView: ItemView {
        let item: DateItem
        let valueView = UIView()
        let dateView  = MPDateView()

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item) {
            self.item = item as! DateItem
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.valueView.addSubview( self.dateView )

            ViewConfiguration( view: self.dateView )
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

class TextItem: ValueItem<String> {
    let placeholder: String?
    let itemUpdate:  (MPSite, String) -> Void

    init(title: String?, placeholder: String?, subitems: [Item] = [ Item ](),
         itemValue: @escaping (MPSite) -> String? = { _ in nil },
         itemUpdate: @escaping (MPSite, String) -> Void = { _, _ in }) {
        self.placeholder = placeholder
        self.itemUpdate = itemUpdate
        super.init( title: title, subitems: subitems, itemValue: itemValue )
    }

    override func createItemView() -> TextItemView {
        return TextItemView( withItem: self )
    }

    class TextItemView: ItemView {
        let item: TextItem
        let valueField = UITextField()

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item) {
            self.item = item as! TextItem
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.valueField.textColor = .white
            self.valueField.textAlignment = .center
            self.valueField.addAction( for: .editingChanged ) { _, _ in
                if let site = self.item.site,
                   let text = self.valueField.text {
                    self.item.itemUpdate( site, text )
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

class StepperItem<V: AdditiveArithmetic & Comparable>: ValueItem<V> {
    let itemUpdate: (MPSite, V) -> Void
    let step:       V, min: V, max: V

    init(title: String? = nil, subitems: [Item] = [ Item ](),
         itemValue: @escaping (MPSite) -> V? = { _ in nil },
         itemUpdate: @escaping (MPSite, V) -> Void = { _, _ in },
         step: V, min: V, max: V) {
        self.itemUpdate = itemUpdate
        self.step = step
        self.min = min
        self.max = max
        super.init( title: title, subitems: subitems, itemValue: itemValue )
    }

    override func createItemView() -> StepperItemView {
        return StepperItemView( withItem: self )
    }

    class StepperItemView: ItemView {
        let item: StepperItem
        let valueView  = UIView()
        let valueLabel = UILabel()
        let downButton = MPButton( title: "-" )
        let upButton   = MPButton( title: "+" )

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item) {
            self.item = item as! StepperItem
            super.init( withItem: item )
        }

        override func createValueView() -> UIView? {
            self.downButton.effectBackground = false
            self.downButton.button.addAction( for: .touchUpInside ) { _, _ in
                if let site = self.item.site,
                   let value = self.item.value,
                   value > self.item.min {
                    self.item.itemUpdate( site, value - self.item.step )
                }
            }

            self.upButton.effectBackground = false
            self.upButton.button.addAction( for: .touchUpInside ) { _, _ in
                if let site = self.item.site,
                   let value = self.item.value,
                   value < self.item.max {
                    self.item.itemUpdate( site, value + self.item.step )
                }
            }

            self.valueLabel.textColor = .white
            self.valueLabel.textAlignment = .center
            if #available( iOS 11.0, * ) {
                self.valueLabel.font = UIFont.preferredFont( forTextStyle: .largeTitle )
            }
            else {
                self.valueLabel.font = UIFont.preferredFont( forTextStyle: .title1 ).withSymbolicTraits( .traitBold )
            }

            self.valueView.addSubview( self.valueLabel )
            self.valueView.addSubview( self.downButton )
            self.valueView.addSubview( self.upButton )

            ViewConfiguration( view: self.valueLabel )
                    .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                    .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                    .constrainTo { $1.centerXAnchor.constraint( equalTo: $0.centerXAnchor ) }
                    .constrainTo { $1.centerYAnchor.constraint( equalTo: $0.centerYAnchor ) }
                    .activate()
            ViewConfiguration( view: self.downButton )
                    .constrainTo { $1.leadingAnchor.constraint( greaterThanOrEqualTo: $0.leadingAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( equalTo: self.valueLabel.leadingAnchor, constant: -20 ) }
                    .constrainTo { $1.centerYAnchor.constraint( equalTo: $0.centerYAnchor ) }
                    .activate()
            ViewConfiguration( view: self.upButton )
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

class PickerItem<V: Equatable>: ValueItem<V> {
    let values:     [V]
    let itemUpdate: (MPSite, V) -> Void
    let itemCell:   (UICollectionView, IndexPath, V) -> UICollectionViewCell
    let viewInit:   (UICollectionView) -> Void

    init(title: String?, values: [V], subitems: [Item] = [ Item ](),
         itemValue: @escaping (MPSite) -> V,
         itemUpdate: @escaping (MPSite, V) -> Void = { _, _ in },
         itemCell: @escaping (UICollectionView, IndexPath, V) -> UICollectionViewCell,
         viewInit: @escaping (UICollectionView) -> Void) {
        self.values = values
        self.itemUpdate = itemUpdate
        self.itemCell = itemCell
        self.viewInit = viewInit

        super.init( title: title, subitems: subitems, itemValue: itemValue )
    }

    override func createItemView() -> PickerItemView {
        return PickerItemView( withItem: self )
    }

    class PickerItemView: ItemView, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
        let item: PickerItem<V>
        let collectionView = CollectionView()

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(withItem item: Item) {
            self.item = item as! PickerItem<V>
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
            if let site = self.item.site,
               let selectedValue = self.item.itemValue( site ),
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
            if let site = self.item.site {
                self.item.itemUpdate( site, self.item.values[indexPath.item] )
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
