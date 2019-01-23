//
// Created by Maarten Billemont on 2018-10-15.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPSiteDetailViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, MPSiteObserver {
    let observers = Observers<MPSiteDetailObserver>()
    let site: MPSite

    let closeButton = MPButton.closeButton()
    let tableView   = UITableView( frame: .zero, style: .plain )
    let items       = [ PasswordCounterItem(),
                        PasswordTypeItem(),
                        SeparatorItem(),
                        LoginTypeItem(),
                        URLItem(),
                        SeparatorItem(),
                        InfoItem() ]

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
        self.closeButton.button.addTarget( self, action: #selector( close ), for: .touchUpInside )

        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.separatorStyle = .none
        self.tableView.layer.cornerRadius = 8
        self.tableView.registerCell( Cell.self )
        let tableViewEffect = UIView( containing: self.tableView, withLayoutMargins: .zero )!
        tableViewEffect.layer.shadowRadius = 8
        tableViewEffect.layer.shadowOpacity = 0.382

        // - Hierarchy
        self.view.addSubview( tableViewEffect )
        self.view.addSubview( self.closeButton )

        // - Layout
        ViewConfiguration( view: tableViewEffect )
                .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.bottomAnchor ) }
                .activate()
        ViewConfiguration( view: self.closeButton )
                .constrainTo { $1.centerXAnchor.constraint( equalTo: tableViewEffect.centerXAnchor ) }
                .constrainTo { $1.centerYAnchor.constraint( equalTo: tableViewEffect.bottomAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                .activate()
    }

    @objc
    func close() {
        self.observers.notify { $0.siteDetailShouldDismiss() }
    }

    // MARK: - UITableViewDelegate

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = Cell.dequeue( from: tableView, indexPath: indexPath ),
            item = self.items[indexPath.item]

        item.site = self.site
        cell.item = item

        return cell
    }

    // MARK: - MPSiteObserver

    func siteDidChange() {
        PearlMainQueue {
            self.tableView.backgroundColor = self.site.color
        }
    }

    // MARK: - Types

    class Cell: UITableViewCell {
        var item: Item? {
            willSet {
                if let item = self.item {
                    item.view.removeFromSuperview()
                }
            }
            didSet {
                if let item = self.item {
                    self.contentView.addSubview( item.view )

                    ViewConfiguration( view: item.view )
                            .constrainToSuperview()
                            .activate()
                }
            }
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(style: CellStyle, reuseIdentifier: String?) {
            super.init( style: style, reuseIdentifier: reuseIdentifier )

            self.backgroundColor = .clear
        }
    }

    class Item: MPSiteObserver {
        let title: String?
        var subitems = [ Item ]()
        let view     = createItemView()

        var valueProvider: ((MPSite) -> String?)?
        var value:         String? {
            get {
                if let site = self.site {
                    return self.valueProvider?( site )
                }
                else {
                    return nil
                }
            }
        }
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

        init(title: String? = nil, subitems: [Item] = [ Item ](), valueProvider: @escaping (MPSite) -> String? = { _ in nil }) {
            self.title = title
            self.subitems = subitems
            self.valueProvider = valueProvider
        }

        class func createItemView() -> ItemView {
            return TextItemView()
        }

        func siteDidChange() {
            PearlMainQueue {
                self.view.updateState( item: self )
            }
        }
    }

    class ItemView: UIView {
        let titleLabel   = UILabel()
        let contentView  = UIStackView()
        let subitemsView = UIStackView()

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        init() {
            super.init( frame: .zero )

            // - View
            self.contentView.axis = .vertical
            self.contentView.spacing = 8

            self.titleLabel.textColor = .white
            self.titleLabel.textAlignment = .center
            self.titleLabel.font = UIFont.preferredFont( forTextStyle: .headline )
            self.contentView.addArrangedSubview( self.titleLabel )

            if let valueView = initValueView() {
                self.contentView.addArrangedSubview( valueView )
            }

            self.subitemsView.axis = .horizontal
            self.subitemsView.spacing = 20
            self.contentView.addArrangedSubview( self.subitemsView )

            // - Hierarchy
            self.addSubview( self.contentView )

            // - Layout
            ViewConfiguration( view: self.contentView )
                    .constrainToSuperview()
                    .activate()
        }

        func initValueView() -> UIView? {
            return nil
        }

        func updateState(item: Item) {
            self.titleLabel.text = item.title
            self.titleLabel.isHidden = item.title == nil

            for i in 0..<max( item.subitems.count, self.subitemsView.arrangedSubviews.count ) {
                let subitemView     = i < item.subitems.count ? item.subitems[i].view: nil
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

    class TextItemView: ItemView {
        let valueView = UILabel()

        override func initValueView() -> UIView? {
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

        override func updateState(item: Item) {
            super.updateState( item: item )

            self.valueView.text = item.value
        }
    }

    class PasswordCounterItem: Item {
        init() {
            super.init( title: "Password Counter" ) { "\($0.counter.rawValue)" }
        }
    }

    class PasswordTypeItem: Item {
        init() {
            super.init( title: "Password Type" ) { String( cString: mpw_longNameForType( $0.resultType ) ) }
        }
    }

    class LoginTypeItem: Item {
        init() {
            super.init( title: "Login Type" ) { String( cString: mpw_longNameForType( $0.loginType ) ) }
        }
    }

    class URLItem: Item {
        init() {
            super.init( title: "URL" ) { $0.url }
        }
    }

    class InfoItem: Item {
        init() {
            super.init( title: nil, subitems: [
                UsesItem(),
                UsedItem(),
                AlgorithmItem(),
            ] )
        }
    }

    class UsesItem: Item {
        init() {
            super.init( title: "Total Uses" ) { "\($0.uses)" }
        }
    }

    class UsedItem: Item {
        init() {
            super.init( title: "Last Used" ) { $0.lastUsed.format() }
        }
    }

    class AlgorithmItem: Item {
        init() {
            super.init( title: "Algorithm" ) { "v\($0.algorithm.rawValue)" }
        }
    }

    class SeparatorItem: Item {
        init() {
            super.init()
        }
    }
}

@objc
protocol MPSiteDetailObserver {
    func siteDetailShouldDismiss()
}
