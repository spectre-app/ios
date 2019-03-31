//
// Created by Maarten Billemont on 2018-10-15.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPSiteDetailViewController: UIViewController, MPSiteObserver {
    let observers = Observers<MPSiteDetailObserver>()
    let site: MPSite

    let items = [ PasswordCounterItem(),
                  PasswordTypeItem(),
                  SeparatorItem(),
                  LoginTypeItem(),
                  URLItem(),
                  SeparatorItem(),
                  InfoItem() ]

    let backgroundView = UIView()
    let itemsView      = UIStackView()
    let closeButton    = MPButton.closeButton()

    // MARK: - Life

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(site: MPSite) {
        self.site = site
        super.init( nibName: nil, bundle: nil )

        site.observers.register( self ).siteDidChange()
    }

    override func viewDidLoad() {

        // - View
        self.backgroundView.layer.cornerRadius = 8
        self.backgroundView.layer.shadowRadius = 8
        self.backgroundView.layer.shadowOpacity = 0.382

        self.itemsView.axis = .vertical
        self.itemsView.spacing = 20
        for item in self.items {
            item.site = self.site
            self.itemsView.addArrangedSubview( item.view )
        }

        self.closeButton.button.addTarget( self, action: #selector( close ), for: .touchUpInside )

        // - Hierarchy
        self.view.addSubview( self.backgroundView )
        self.backgroundView.addSubview( self.itemsView )
        self.view.addSubview( self.closeButton )

        // - Layout
        ViewConfiguration( view: self.backgroundView )
                .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.bottomAnchor ) }
                .activate()
        ViewConfiguration( view: self.itemsView )
                .constrainToSuperview( withMargins: true, forAttributes: [ .alignAllTop, .alignAllBottom ] )
                .constrainToSuperview( withMargins: false, forAttributes: [ .alignAllLeading, .alignAllTrailing ] )
                .activate()
        ViewConfiguration( view: self.closeButton )
                .constrainTo { $1.centerXAnchor.constraint( equalTo: self.backgroundView.centerXAnchor ) }
                .constrainTo { $1.centerYAnchor.constraint( equalTo: self.backgroundView.bottomAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                .activate()
    }

    @objc
    func close() {
        self.observers.notify { $0.siteDetailShouldDismiss() }
    }

    // MARK: - MPSiteObserver

    func siteDidChange() {
        PearlMainQueue {
            self.backgroundView.backgroundColor = self.site.color
        }
    }

    // MARK: - Types

    class Item: MPSiteObserver {
        let title:    String?
        let subitems: [Item]
        lazy var view = createItemView()
        var updateOperation: Operation?

        var site: MPSite? {
            willSet {
                self.site?.observers.unregister( self )
            }
            didSet {
                self.site?.observers.register( self ).siteDidChange()
                ({
                     for subitem in self.subitems {
                         subitem.site = self.site
                     }
                 }()) // this is a hack to get around Swift silently skipping recursive didSet on properties.
            }
        }

        init(title: String? = nil, subitems: [Item] = [ Item ]()) {
            self.title = title
            self.subitems = subitems
        }

        func createItemView() -> ItemView {
            fatalError( "createItemView must be overridden" )
        }

        func siteDidChange() {
            self.setNeedsUpdate()
        }

        func setNeedsUpdate() {
            guard self.updateOperation == nil
            else { return }

            self.updateOperation = PearlMainQueueOperation {
                self.view.update()
                self.updateOperation = nil
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
                self.contentView.addArrangedSubview( self.subitemsView )

                // - Hierarchy
                self.addSubview( self.contentView )

                // - Layout
                ViewConfiguration( view: self.contentView )
                        .constrainToSuperview()
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

    class ValueItem<V>: Item {
        let valueProvider: ((MPSite) -> V?)?
        var value:         V? {
            get {
                if let site = self.site {
                    return self.valueProvider?( site )
                }
                else {
                    return nil
                }
            }
        }

        init(title: String? = nil, subitems: [Item] = [ Item ](), valueProvider: @escaping (MPSite) -> V? = { _ in nil }) {
            self.valueProvider = valueProvider
            super.init( title: title, subitems: subitems )
        }
    }

    class TextItem: ValueItem<String> {
        override func createItemView() -> TextItemView {
            return TextItemView( withItem: self )
        }

        class TextItemView: ItemView {
            let item: TextItem
            let valueView = UILabel()

            required init?(coder aDecoder: NSCoder) {
                fatalError( "init(coder:) is not supported for this class" )
            }

            override init(withItem item: Item) {
                self.item = item as! TextItem
                super.init( withItem: item )
            }

            override func createValueView() -> UIView? {
                self.valueView.textColor = .white
                self.valueView.textAlignment = .center
                if #available( iOS 11.0, * ) {
                    self.valueView.font = UIFont.preferredFont( forTextStyle: .largeTitle )
                }
                else {
                    self.valueView.font = UIFont.preferredFont( forTextStyle: .title1 ).withSymbolicTraits( .traitBold )
                }
                return self.valueView
            }

            override func update() {
                super.update()

                self.valueView.text = self.item.value
            }
        }
    }

    class PickerItem<V>: ValueItem<V> {
        let options:   [V]
        let valueCell: (UICollectionView, IndexPath, V) -> String

        init(title: String?, options: [V], subitems: [ValueItem<Any>] = [ ValueItem ](), valueProvider: @escaping (MPSite) -> V?, valueCell: @escaping (V) -> String) {
            self.options = options
            self.valueCell = valueCell
            super.init( title: title, subitems: subitems, valueProvider: valueProvider )
        }

        override func createItemView() -> PickerItemView {
            return PickerItemView( withItem: self )
        }

        class PickerItemView: ItemView, UICollectionViewDelegate, UICollectionViewDataSource {
            let item: PickerItem<V>
            let valueView = UICollectionView( frame: .zero, collectionViewLayout: UICollectionViewFlowLayout() )

            required init?(coder aDecoder: NSCoder) {
                fatalError( "init(coder:) is not supported for this class" )
            }

            override init(withItem item: Item) {
                self.item = item as! PickerItem<V>
                super.init( withItem: item )
            }

            override func createValueView() -> UIView? {
                self.valueView.delegate = self
                self.valueView.dataSource = self
                return self.valueView
            }

            override func update() {
                super.update()

                self.valueView.reloadAllComponents()
            }

            // MARK: - UICollectionViewDelegate

            // MARK: - UICollectionViewDataSource
            func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
                return self.item.options.count
            }

            func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
                return self.item.valueCell( collectionView, indexPath, self.item.options[indexPath.item] )
            }
        }
    }

    class PasswordCounterItem: TextItem {
        init() {
            super.init( title: "Password Counter" ) { "\($0.counter.rawValue)" }
        }
    }

    class PasswordTypeItem: PickerItem<MPResultType> {
        init() {
            super.init( title: "Password Type", options: [ MPResultType ]( MPResultTypes ),
                        valueProvider: { $0.resultType },
                        valueCell: { type in } )
        }
    }

    class LoginTypeItem: PickerItem<MPResultType> {
        init() {
            super.init( title: "Login Type", options: [ MPResultType ]( MPResultTypes ),
                        valueProvider: { $0.loginType },
                        valueRenderer: { String( cString: mpw_longNameForType( $0 ) ) } )
        }
    }

    class URLItem: TextItem {
        init() {
            super.init( title: "URL" ) { $0.url }
        }
    }

    class InfoItem: TextItem {
        init() {
            super.init( title: nil, subitems: [
                UsesItem(),
                UsedItem(),
                AlgorithmItem(),
            ] )
        }
    }

    class DebugItem: Item {
        init() {
            super.init( title: "Debug Item" )
        }

        override func createItemView() -> ItemView {
            return DebugItemView( withItem: self )
        }

        class DebugItemView: ItemView {
            required init?(coder aDecoder: NSCoder) {
                fatalError( "init(coder:) is not supported for this class" )
            }

            override init(withItem item: Item) {
                super.init( withItem: item )
            }

            override func createValueView() -> UIView? {
                return nil
            }
        }
    }

    class UsesItem: TextItem {
        init() {
            super.init( title: "Total Uses" ) { "\($0.uses)" }
        }
    }

    class UsedItem: TextItem {
        init() {
            super.init( title: "Last Used" ) { $0.lastUsed.format() }
        }
    }

    class AlgorithmItem: TextItem {
        init() {
            super.init( title: "Algorithm" ) { "v\($0.algorithm.rawValue)" }
        }
    }

    class SeparatorItem: TextItem {
        init() {
            super.init()
        }
    }
}

@objc
protocol MPSiteDetailObserver {
    func siteDetailShouldDismiss()
}
