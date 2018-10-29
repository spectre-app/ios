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
    let items = [ Item( title: "Counter", valueProvider: { "\($0.counter.rawValue)" } ),
                  Item( title: "Password Type", valueProvider: { String( cString: mpw_longNameForType( $0.resultType ) ) } ),
                  Item( title: "Login Type", valueProvider: { String( cString: mpw_longNameForType( $0.loginType ) ) } ),
                  Item( title: "Algorithm", valueProvider: { "V\($0.algorithm.rawValue)" } ),
                  Item( title: "URL", valueProvider: { $0.url } ),
                  Item( title: "Last Used", valueProvider: { $0.lastUsed.format() } ),
                  Item( title: "Total Uses", valueProvider: { "\($0.uses)" } ) ]

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
                .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                .activate()
        ViewConfiguration( view: self.closeButton )
                .constrainTo { $1.centerXAnchor.constraint( equalTo: tableViewEffect.centerXAnchor ) }
                .constrainTo { $1.centerYAnchor.constraint( equalTo: tableViewEffect.bottomAnchor ) }
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
            for cell in self.tableView.visibleCells {
                if let cell = cell as? Cell {
                    cell.item?.site = self.site
                }
            }
        }
    }

    // MARK: - Types

    class Cell: UITableViewCell {
        var item: Item? {
            didSet {
                self.textLabel?.text = self.item?.title
                self.detailTextLabel?.text = self.item?.value
            }
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(style: CellStyle, reuseIdentifier: String?) {
            super.init( style: .value1, reuseIdentifier: reuseIdentifier )
        }
    }

    class Item {
        var site:          MPSite?
        var title:         String
        var valueProvider: (MPSite) -> String?
        var value:         String? {
            get {
                if let site = self.site {
                    return self.valueProvider( site )
                }
                else {
                    return nil
                }
            }
        }

        init(title: String, valueProvider: @escaping (MPSite) -> String?) {
            self.title = title
            self.valueProvider = valueProvider
        }
    }
}

@objc
protocol MPSiteDetailObserver {
    func siteDetailShouldDismiss()
}
