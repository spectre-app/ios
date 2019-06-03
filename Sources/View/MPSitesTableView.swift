//
// Created by Maarten Billemont on 2018-03-25.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class MPSitesTableView: UITableView, UITableViewDelegate, UITableViewDataSource, MPUserObserver {
    public let observers = Observers<MPSitesViewObserver>()
    public var user: MPUser? {
        willSet {
            self.user?.observers.unregister( self )
        }
        didSet {
            self.user?.observers.register( self )
            self.query = nil
        }
    }
    public var selectedSite: MPSite? {
        didSet {
            self.observers.notify { $0.siteWasSelected( selectedSite: self.selectedSite ) }
        }
    }
    public var query: String? {
        didSet {
            self.updateSites()
        }
    }

    private let data        = NSMutableArray()
    private var newSiteResult: MPQuery.Result<MPSite>?
    private var isSelecting = false, isInitial = true

    // MARK: --- Life ---

    init() {
        super.init( frame: .zero, style: .plain )

        self.registerCell( SiteCell.self )
        self.delegate = self
        self.dataSource = self
        self.backgroundColor = .clear
        self.isOpaque = false
        self.separatorStyle = .none
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    // MARK: --- Internal ---

    func dataSection(section: Int) -> NSArray {
        return self.data.object( at: section ) as! NSArray
    }

    func dataRow(section: Int, row: Int) -> MPQuery.Result<MPSite> {
        return self.dataSection( section: section ).object( at: row ) as! MPQuery.Result<MPSite>
    }

    func updateSites() {
        DispatchQueue.global().async {
            // Determine search state and filter user sites
            var selectedResult = self.data.reduce( nil, { result, section in
                result ?? (section as? [MPQuery.Result<MPSite>])?.first { $0.value == self.selectedSite }
            } )
            let selectionFollowsQuery = selectedResult == self.newSiteResult || selectedResult?.exact ?? false
            let results = MPQuery( self.query ).find( self.user?.sites.sorted() ?? [] ) { $0.siteName }
            let exactResult = results.first { $0.exact }
            let newSites: NSMutableArray = [ results ]

            // Add "new site" result
            if let user = self.user,
               let query = self.query,
               !query.isEmpty, exactResult == nil {
                if let newSiteResult = self.newSiteResult {
                    newSiteResult.value.siteName = query
                }
                else {
                    self.newSiteResult = MPQuery.Result<MPSite>( value: MPSite( user: user, named: query ), keySupplier: { $0.siteName } )
                }
                if let newSiteResult = self.newSiteResult {
                    newSiteResult.matches( query: query )
                    newSites.add( [ newSiteResult ] )
                }
            }
            else {
                self.newSiteResult = nil
            }

            // Special case for selected site: keep selection on the site result that matches the query
            if selectionFollowsQuery {
                selectedResult = exactResult ?? self.newSiteResult
                self.selectedSite = selectedResult?.value
            }

            // Update the sites table to show the newly filtered sites
            DispatchQueue.main.perform {
                self.updateDataSource( self.data, toSections: newSites, reloadItems: nil, with: self.isInitial ? .none: .automatic )
                self.isInitial = false

                // Light-weight reload the cell content without fully reloading the cell rows.
                for (s, section) in (self.data as? [[MPQuery.Result<MPSite>]] ?? []).enumerated() {
                    for (r, row) in section.enumerated() {
                        (self.cellForRow( at: IndexPath( row: r, section: s ) ) as? SiteCell)?.result = row
                    }
                }

                // Select the most appropriate row according to the query.
                if let selectedPath = self.find( inDataSource: self.data, item: selectedResult ) {
                    self.selectRow( at: selectedPath, animated: true, scrollPosition: .middle )
                }
            }
        }
    }

    // MARK: --- UITableViewDelegate ---

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.selectRow( at: nil, animated: true, scrollPosition: .none )
        self.selectedSite = nil
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        self.isSelecting = true;
        return indexPath
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if !self.isSelecting {
            self.selectedSite = nil
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.selectedSite = self.dataRow( section: indexPath.section, row: indexPath.row ).value
        self.isSelecting = false
    }

    // MARK: --- UITableViewDataSource ---

    func numberOfSections(in tableView: UITableView) -> Int {
        return self.data.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int)
                    -> Int {
        return self.dataSection( section: section ).count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
                    -> UITableViewCell {
        let cell = SiteCell.dequeue( from: tableView, indexPath: indexPath )
        cell.result = self.dataRow( section: indexPath.section, row: indexPath.row )
        cell.new = cell.result == self.newSiteResult

        return cell
    }

    // MARK: --- MPUserObserver ---

    func userDidLogin(_ user: MPUser) {
        DispatchQueue.main.perform {
            self.updateSites()
        }
    }

    func userDidLogout(_ user: MPUser) {
        DispatchQueue.main.perform {
            self.updateSites()
        }
    }

    func userDidChange(_ user: MPUser) {
    }

    func userDidUpdateSites(_ user: MPUser) {
        DispatchQueue.main.perform {
            self.updateSites()
        }
    }

    // MARK: --- Types ---

    class SiteCell: UITableViewCell, MPSiteObserver {
        public var result: MPQuery.Result<MPSite>? {
            didSet {
                self.site = self.result?.value
            }
        }
        public var site:   MPSite? {
            willSet {
                self.site?.observers.unregister( self )
            }
            didSet {
                if let site = self.site {
                    site.observers.register( self ).siteDidChange( site )
                }
            }
        }
        public var new = false {
            didSet {
                DispatchQueue.main.perform {
                    self.copyButton.title = self.new ? "add": "copy"
                }
            }
        }

        private let indicatorView = UIView()
        private let passwordLabel = UILabel()
        private let nameLabel     = UILabel()
        private let scrollView    = UIScrollView()
        private let cellGuide     = UIView()
        private let loginButton   = MPButton( image: nil, title: "login" )
        private let copyButton    = MPButton( image: nil, title: "copy" )

        // MARK: --- Life ---

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
            super.init( style: style, reuseIdentifier: reuseIdentifier )

            // - View
            self.isOpaque = false
            self.clipsToBounds = true
            self.backgroundColor = .clear
            self.selectedBackgroundView = UIView()
            self.selectedBackgroundView?.backgroundColor = UIColor( red: 0.4, green: 0.8, blue: 1, alpha: 0.3 )

            self.indicatorView.backgroundColor = UIColor( white: 0, alpha: 0.6 )
            self.indicatorView.layer.cornerRadius = 4
            self.indicatorView.layer.borderWidth = 1
            self.indicatorView.layer.borderColor = UIColor( white: 0, alpha: 1 ).cgColor

            self.passwordLabel.text = " "
            self.passwordLabel.font = UIFont.passwordFont
            self.passwordLabel.adjustsFontSizeToFitWidth = true
            self.passwordLabel.textAlignment = .natural
            self.passwordLabel.textColor = UIColor( red: 0.4, green: 0.8, blue: 1, alpha: 1 )
            self.passwordLabel.shadowColor = .black

            self.nameLabel.font = .preferredFont( forTextStyle: .caption1 )
            self.nameLabel.textAlignment = .natural
            self.nameLabel.textColor = .lightText
            self.nameLabel.shadowColor = .black

            self.loginButton.darkBackground = true
            self.loginButton.button.addAction( for: .touchUpInside ) { _, _ in self.loginAction() }
            self.loginButton.button.setContentCompressionResistancePriority( .defaultHigh + 1, for: .horizontal )

            self.copyButton.darkBackground = true
            self.copyButton.button.addAction( for: .touchUpInside ) { _, _ in self.copyAction() }
            self.copyButton.button.setContentCompressionResistancePriority( .defaultHigh + 1, for: .horizontal )

            // - Hierarchy
            self.contentView.addSubview( self.scrollView )
            self.scrollView.addSubview( self.cellGuide )
            self.scrollView.addSubview( self.passwordLabel )
            self.scrollView.addSubview( self.nameLabel )
            self.scrollView.addSubview( self.copyButton )
            self.scrollView.addSubview( self.loginButton )

            // - Layout
            LayoutConfiguration( view: self.scrollView )
                    .constrainToOwner()
                    .activate()

            LayoutConfiguration( view: self.cellGuide )
                    .constrain( to: self.contentView, withMargins: true, anchor: .vertically )
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor, constant: 20 /* contentView.layoutMargins.leading */ ) }
                    .constrainTo { $1.widthAnchor.constraint( equalTo: self.contentView.layoutMarginsGuide.widthAnchor ) }
                    .activate()

            LayoutConfiguration( view: self.passwordLabel )
                    .constrainTo { $1.topAnchor.constraint( greaterThanOrEqualTo: $0.topAnchor ) }
                    .constrainTo { $1.topAnchor.constraint( equalTo: self.cellGuide.topAnchor ) }
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: self.cellGuide.leadingAnchor ) }
                    .huggingPriorityHorizontal( .fittingSizeLevel, vertical: .fittingSizeLevel )
                    .activate()

            LayoutConfiguration( view: self.nameLabel )
                    .constrainTo { $1.topAnchor.constraint( equalTo: self.passwordLabel.bottomAnchor ) }
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: self.passwordLabel.leadingAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( lessThanOrEqualTo: self.passwordLabel.trailingAnchor ) }
                    .constrainTo { $1.bottomAnchor.constraint( equalTo: self.cellGuide.bottomAnchor ) }
                    .constrainTo { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.bottomAnchor ) }
                    .activate()

            LayoutConfiguration( view: self.copyButton )
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: self.passwordLabel.trailingAnchor, constant: 20 ) }
                    .constrainTo { $1.centerYAnchor.constraint( equalTo: $0.centerYAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( equalTo: self.cellGuide.trailingAnchor ) }
                    .activate()

            LayoutConfiguration( view: self.loginButton )
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: self.copyButton.trailingAnchor, constant: 4 ) }
                    .constrainTo { $1.centerYAnchor.constraint( equalTo: $0.centerYAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                    .activate()
        }

        func loginAction() {
        }

        func copyAction() {
            DispatchQueue.mpw.perform {
                if let site = self.site,
                   let password = site.mpw_result() {
                    if self.new {
                        site.user.sites.append( site )
                    }

                    if #available( iOS 10.0, * ) {
                        UIPasteboard.general.setItems(
                                [ [ UIPasteboardTypeAutomatic: password ] ],
                                options: [
                                    UIPasteboard.OptionsKey.localOnly: true,
                                    UIPasteboard.OptionsKey.expirationDate: Date( timeIntervalSinceNow: 3 * 60 )
                                ] )

                        DispatchQueue.main.perform {
                            MPAlertView( title: site.siteName, message: "Password Copied (3 min)" ).show( in: self )
                        }
                    }
                    else {
                        UIPasteboard.general.string = password

                        DispatchQueue.main.perform {
                            MPAlertView( title: site.siteName, message: "Password Copied" ).show( in: self )
                        }
                    }
                }
            }
        }

        // MARK: --- MPSiteObserver ---

        func siteDidChange(_ site: MPSite) {
            DispatchQueue.main.perform {
                self.nameLabel.attributedText = self.result?.attributedKey
                self.indicatorView.backgroundColor = self.site?.color?.withAlphaComponent( 0.85 )
            }
            DispatchQueue.mpw.perform {
                let password = self.site?.mpw_result()

                DispatchQueue.main.perform {
                    self.passwordLabel.text = password ?? " "
                }
            }
        }
    }
}

@objc
protocol MPSitesViewObserver {
    func siteWasSelected(selectedSite: MPSite?)
}
