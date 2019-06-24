//
// Created by Maarten Billemont on 2018-03-25.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class MPSitesTableView: UITableView, UITableViewDelegate, UITableViewDataSource, Observable, MPUserObserver {
    public let observers = Observers<MPSitesViewObserver>()
    public var user: MPUser? {
        willSet {
            self.user?.observers.unregister( observer: self )
        }
        didSet {
            self.user?.observers.register( observer: self )
            self.query = nil
        }
    }
    public var selectedSite: MPSite? {
        didSet {
            if self.selectedSite != oldValue {
                self.observers.notify { $0.siteWasSelected( selectedSite: self.selectedSite ) }
            }
        }
    }
    public var query: String? {
        didSet {
            if self.query != oldValue || self.data.count == 0 {
                self.updateSites()
            }
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
            let selectionFollowsQuery = self.newSiteResult === selectedResult || selectedResult?.exact ?? false
            let results = MPQuery( self.query ).find( self.user?.sites.sorted() ?? [] ) { $0.siteName }
            let exactResult = results.first { $0.exact }
            let newSites: NSMutableArray = [ results ]

            // Add "new site" result if there is a query and no exact result
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
            }
            if self.newSiteResult != selectedResult,
               let selectedResult_ = selectedResult,
               !results.contains( selectedResult_ ) {
                selectedResult = nil
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
                self.selectRow( at: self.find( inDataSource: self.data, item: selectedResult ), animated: true, scrollPosition: .middle )
                self.selectedSite = selectedResult?.value
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
        let result = self.dataRow( section: indexPath.section, row: indexPath.row )
        if AvCell.is( result: result ) {
            return AvCell.dequeue( from: tableView, indexPath: indexPath )
        }

        let cell = SiteCell.dequeue( from: tableView, indexPath: indexPath )
        cell.result = result
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
                self.site?.observers.unregister( observer: self )
            }
            didSet {
                if let site = self.site {
                    site.observers.register( observer: self ).siteDidChange( site )
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

        private var mode        = MPKeyPurpose.authentication {
            didSet {
                self.modeButton.title = self.mode.button()
                self.modeButton.size = .small
                self.updateResult()
            }
        }
        private let resultLabel = UILabel()
        private let nameLabel   = UILabel()
        private let modeButton  = MPButton( image: nil, title: "" )
        private let copyButton  = MPButton( image: nil, title: "" )

        // MARK: --- Life ---

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
            defer {
                self.mode = { self.mode }()
            }
            super.init( style: style, reuseIdentifier: reuseIdentifier )

            // - View
            self.isOpaque = false
            self.clipsToBounds = true
            self.backgroundColor = .clear
            self.selectedBackgroundView = UIView()
            self.selectedBackgroundView?.backgroundColor = MPTheme.global.color.selection.get()

            self.resultLabel.text = " "
            self.resultLabel.font = MPTheme.global.font.password.get()
            self.resultLabel.adjustsFontSizeToFitWidth = true
            self.resultLabel.textAlignment = .natural
            self.resultLabel.textColor = MPTheme.global.color.password.get()
            self.resultLabel.shadowColor = MPTheme.global.color.shadow.get()

            self.nameLabel.font = MPTheme.global.font.caption1.get()
            self.nameLabel.textAlignment = .natural
            self.nameLabel.textColor = MPTheme.global.color.body.get()
            self.nameLabel.shadowColor = MPTheme.global.color.shadow.get()

            self.modeButton.tapEffect = false
            self.modeButton.darkBackground = true
            self.modeButton.button.addAction( for: .touchUpInside ) { _, _ in self.modeAction() }
            self.modeButton.button.setContentCompressionResistancePriority( .defaultHigh + 1, for: .horizontal )

            self.copyButton.darkBackground = true
            self.copyButton.button.addAction( for: .touchUpInside ) { _, _ in self.copyAction() }
            self.copyButton.button.setContentCompressionResistancePriority( .defaultHigh + 1, for: .horizontal )

            // - Hierarchy
            self.contentView.addSubview( self.resultLabel )
            self.contentView.addSubview( self.nameLabel )
            self.contentView.addSubview( self.modeButton )
            self.contentView.addSubview( self.copyButton )

            // - Layout
            LayoutConfiguration( view: self.modeButton )
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                    .constrainTo { $1.centerYAnchor.constraint( equalTo: self.resultLabel.centerYAnchor ) }
                    .activate()

            LayoutConfiguration( view: self.resultLabel )
                    .constrainTo { $1.topAnchor.constraint( greaterThanOrEqualTo: $0.layoutMarginsGuide.topAnchor ) }
                    .constrainTo { $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.topAnchor ) }
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: self.modeButton.trailingAnchor, constant: 4 ) }
                    .huggingPriorityHorizontal( .fittingSizeLevel, vertical: .fittingSizeLevel )
                    .activate()

            LayoutConfiguration( view: self.nameLabel )
                    .constrainTo { $1.topAnchor.constraint( equalTo: self.resultLabel.bottomAnchor ) }
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( lessThanOrEqualTo: self.resultLabel.trailingAnchor ) }
                    .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.layoutMarginsGuide.bottomAnchor ) }
                    .constrainTo { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.layoutMarginsGuide.bottomAnchor ) }
                    .activate()

            LayoutConfiguration( view: self.copyButton )
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: self.resultLabel.trailingAnchor, constant: 20 ) }
                    .constrainTo { $1.centerYAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerYAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                    .activate()
        }

        func modeAction() {
            self.mode.next()
        }

        func copyAction() {
            DispatchQueue.mpw.perform {
                guard let site = self.site
                else {
                    return
                }
                var result = "", kind = ""
                switch self.mode {
                    case .authentication:
                        result = site.mpw_result() ?? ""
                        kind = "password"
                    case .identification:
                        result = site.mpw_login() ?? ""
                        kind = "user name"
                    case .recovery:
                        result = site.mpw_answer() ?? ""
                        kind = "security answer"
                }

                site.use()
                if self.new {
                    site.user.sites.append( site )
                }

                if #available( iOS 10.0, * ) {
                    UIPasteboard.general.setItems(
                            [ [ UIPasteboardTypeAutomatic: result ] ],
                            options: [
                                UIPasteboard.OptionsKey.localOnly: true,
                                UIPasteboard.OptionsKey.expirationDate: Date( timeIntervalSinceNow: 3 * 60 )
                            ] )

                    DispatchQueue.main.perform {
                        MPAlertView( title: site.siteName, message: "Copied \(kind) (3 min)", details:
                        """
                        Your \(kind) for \(site.siteName) is:
                        \(result)

                        It was copied to the pasteboard, you can now switch to your application and paste it into the \(kind) field.

                        Note that after 3 minutes, the \(kind) will be removed from the pasteboard for security reasons.
                        """ ).show( in: self )
                    }
                }
                else {
                    UIPasteboard.general.string = result

                    DispatchQueue.main.perform {
                        MPAlertView( title: site.siteName, message: "Copied \(kind)", details:
                        """
                        Your \(kind) for \(site.siteName) is:
                        \(result)

                        It was copied to the pasteboard, you can now switch to your application and paste it into the \(kind) field.
                        """ ).show( in: self )
                    }
                }
            }
        }

        // MARK: --- MPSiteObserver ---

        func siteDidChange(_ site: MPSite) {
            DispatchQueue.main.perform {
                self.nameLabel.attributedText = self.result?.attributedKey
            }
            self.updateResult()
        }

        private func updateResult() {
            DispatchQueue.mpw.perform {
                var result: String?
                switch self.mode {
                    case .authentication:
                        result = self.site?.mpw_result()
                    case .identification:
                        result = self.site?.mpw_login()
                    case .recovery:
                        result = self.site?.mpw_answer()
                }

                DispatchQueue.main.perform {
                    self.resultLabel.text = result ?? " "
                }
            }
        }
    }

    class AvCell: UITableViewCell {
        private let propLabel = UILabel()

        class func `is`(result: MPQuery.Result<MPSite>) -> Bool {
            return result.value.siteName == "avonlea"
        }

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
            self.selectedBackgroundView?.backgroundColor = MPTheme.global.color.selection.get()
            self.contentView.layoutMargins = UIEdgeInsets( top: 80, left: 80, bottom: 80, right: 80 )

            self.propLabel.font = MPTheme.global.font.largeTitle.get()
            self.propLabel.text = "💁"

            // - Hierarchy
            self.contentView.addSubview( self.propLabel )

            // - Layout
            LayoutConfiguration( view: self.propLabel )
                    .constrainToMarginsOfOwner()
                    .activate()
        }
    }
}

@objc
protocol MPSitesViewObserver {
    func siteWasSelected(selectedSite: MPSite?)
}
