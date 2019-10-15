//
// Created by Maarten Billemont on 2018-03-25.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit
import AVKit

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
            if self.query != oldValue {
                self.updateTask.request()
            }
        }
    }

    private lazy var resultSource = DataSource<MPQuery.Result<MPSite>>( tableView: self )
    private var newSiteResult: MPQuery.Result<MPSite>?
    private var isSelecting = false, isInitial = true
    private lazy var updateTask = DispatchTask( queue: DispatchQueue.main, qos: .userInitiated, deadline: .now() + .milliseconds( 100 ) ) {
        self.doUpdate()
    }

    // MARK: --- Life ---

    init() {
        super.init( frame: .zero, style: .plain )

        self.registerCell( SiteCell.self )
        self.registerCell( LiefsteCell.self )
        self.delegate = self
        self.dataSource = self
        self.backgroundColor = .clear
        self.isOpaque = false
        self.separatorStyle = .singleLine
        self.separatorColor = MPTheme.global.color.mute.get()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        self.updateTask.request()
    }

    // MARK: --- Internal ---

    func doUpdate() {
        DispatchQueue.global().async { [weak self] in
            guard let self = self
            else { return }

            var selectedResult: MPQuery.Result<MPSite>?
            var resultSource = [ [ MPQuery.Result<MPSite>? ] ]()
            if let user = self.user, user.masterKeyFactory != nil {

                // Determine search state and filter user sites
                selectedResult = self.resultSource.elements().first( where: { $1?.value === self.selectedSite } )?.element
                let selectionFollowsQuery = self.newSiteResult === selectedResult || selectedResult?.exact ?? false
                let results = MPQuery( self.query ).find( user.sites.sorted() ) { $0.siteName }
                let exactResult = results.first { $0.exact }
                resultSource.append( results )

                // Add "new site" result if there is a query and no exact result
                if let query = self.query,
                   !query.isEmpty, exactResult == nil {
                    self.newSiteResult?.value.siteName = query

                    if self.newSiteResult == nil || LiefsteCell.is( result: self.newSiteResult ) {
                        self.newSiteResult = MPQuery.Result<MPSite>( value: MPSite( user: user, siteName: query ), keySupplier: { $0.siteName } )
                    }

                    self.newSiteResult?.matches( query: query )
                    resultSource.append( [ self.newSiteResult ] )
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
            }

            // Update the sites table to show the newly filtered sites
            DispatchQueue.main.perform { [weak self] in
                guard let self = self
                else { return }

                self.resultSource.update( resultSource, animated: !self.isInitial )
                self.isInitial = false

                // Light-weight reload the cell content without fully reloading the cell rows.
                self.resultSource.elements().forEach { path, element in
                    (self.cellForRow( at: path ) as? SiteCell)?.result = element
                }

                // Select the most appropriate row according to the query.
                self.selectRow( at: self.resultSource.indexPath( for: selectedResult ), animated: true, scrollPosition: .middle )
                self.selectedSite = selectedResult?.value
            }
        }
    }

    // MARK: --- UITableViewDelegate ---

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
//        self.selectRow( at: nil, animated: true, scrollPosition: .none )
//        self.selectedSite = nil
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
        self.selectedSite = self.resultSource.element( at: indexPath )?.value
        self.isSelecting = false
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        (cell as? LiefsteCell)?.willDisplay()
    }

    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        (cell as? LiefsteCell)?.didEndDisplaying()
    }

    // MARK: --- UITableViewDataSource ---

    func numberOfSections(in tableView: UITableView) -> Int {
        self.resultSource.numberOfSections
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.resultSource.numberOfItems( in: section )
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let result = self.resultSource.element( at: indexPath )
        if LiefsteCell.is( result: result ) {
            return LiefsteCell.dequeue( from: tableView, indexPath: indexPath )
        }

        let cell = SiteCell.dequeue( from: tableView, indexPath: indexPath )
        cell.result = result
        cell.new = cell.result == self.newSiteResult
        return cell
    }

    // MARK: --- MPUserObserver ---

    func userDidLogin(_ user: MPUser) {
        self.updateTask.request()
    }

    func userDidLogout(_ user: MPUser) {
        self.updateTask.request()
    }

    func userDidChange(_ user: MPUser) {
        self.updateTask.request()
    }

    func userDidUpdateSites(_ user: MPUser) {
        self.updateTask.request()
    }

    // MARK: --- Types ---

    class SiteCell: UITableViewCell, MPSiteObserver, MPUserObserver {
        public var result: MPQuery.Result<MPSite>? {
            didSet {
                self.site = self.result?.value
            }
        }
        public var site:   MPSite? {
            willSet {
                self.site?.observers.unregister( observer: self )
                self.site?.user.observers.unregister( observer: self )
            }
            didSet {
                if let site = self.site {
                    site.observers.register( observer: self ).siteDidChange( site )
                    site.user.observers.register( observer: self ).userDidChange( site.user )
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
                self.update()
            }
        }
        private let resultLabel = UITextField()
        private let nameLabel   = UILabel()
        private let modeButton  = MPButton( title: "" )
        private let copyButton  = MPButton( title: "" )

        // MARK: --- Life ---

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init( style: style, reuseIdentifier: reuseIdentifier )

            // - View
            self.isOpaque = false
            self.clipsToBounds = true
            self.backgroundColor = .clear
            if #available( iOS 11, * ) {
                self.contentView.insetsLayoutMarginsFromSafeArea = false
            }

            self.selectedBackgroundView = UIView()
            self.selectedBackgroundView?.backgroundColor = MPTheme.global.color.selection.get()

            self.resultLabel.adjustsFontSizeToFitWidth = true
            self.resultLabel.font = MPTheme.global.font.password.get()
            self.resultLabel.text = " "
            self.resultLabel.textAlignment = .natural
            self.resultLabel.isEnabled = false

            self.nameLabel.font = MPTheme.global.font.caption1.get()
            self.nameLabel.textAlignment = .natural
            self.nameLabel.textColor = MPTheme.global.color.body.get()
            self.nameLabel.shadowColor = MPTheme.global.color.shadow.get()
            self.nameLabel.shadowOffset = CGSize( width: 0, height: 1 )

            self.modeButton.tapEffect = false
//            self.modeButton.darkBackground = true
//            self.modeButton.effectBackground = false
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
                    .constrainTo { $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.topAnchor ) }
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: self.modeButton.trailingAnchor, constant: 4 ) }
                    .huggingPriorityHorizontal( .fittingSizeLevel, vertical: .defaultLow )
                    .compressionResistancePriorityHorizontal( .defaultHigh - 1, vertical: .defaultHigh + 1 )
                    .activate()

            LayoutConfiguration( view: self.nameLabel )
                    .constrainTo { $1.topAnchor.constraint( equalTo: self.resultLabel.bottomAnchor ) }
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( lessThanOrEqualTo: self.resultLabel.trailingAnchor ) }
                    .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.layoutMarginsGuide.bottomAnchor ) }
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
                else { return }

                var result = "", kind = ""
                switch self.mode {
                    case .authentication:
                        result = (try? site.mpw_result().await()) ?? ""
                        kind = "password"
                    case .identification:
                        result = (try? site.mpw_login().await()) ?? ""
                        kind = "user name"
                    case .recovery:
                        result = (try? site.mpw_answer().await()) ?? ""
                        kind = "security answer"
                    @unknown default: ()
                }

                site.use()
                if self.new {
                    site.user.sites.append( site )
                }

                if #available( iOS 10.0, * ) {
                    UIPasteboard.general.setItems(
                            [ [ UIPasteboard.typeAutomatic: result ] ],
                            options: [
                                UIPasteboard.OptionsKey.localOnly: true,
                                UIPasteboard.OptionsKey.expirationDate: Date( timeIntervalSinceNow: 3 * 60 )
                            ] )

                    MPAlert( title: site.siteName, message: "Copied \(kind) (3 min)", details:
                    """
                    Your \(kind) for \(site.siteName) is:
                    \(result)

                    It was copied to the pasteboard, you can now switch to your application and paste it into the \(kind) field.

                    Note that after 3 minutes, the \(kind) will expire from the pasteboard for security reasons.
                    """ ).show( in: self )
                }
                else {
                    UIPasteboard.general.string = result

                    MPAlert( title: site.siteName, message: "Copied \(kind)", details:
                    """
                    Your \(kind) for \(site.siteName) is:
                    \(result)

                    It was copied to the pasteboard, you can now switch to your application and paste it into the \(kind) field.
                    """ ).show( in: self )
                }
            }
        }

        // MARK: --- MPUserObserver ---

        func userDidChange(_ user: MPUser) {
            DispatchQueue.main.perform {
                self.resultLabel.isSecureTextEntry = self.site?.user.maskPasswords ?? true
            }
        }

        // MARK: --- MPSiteObserver ---

        func siteDidChange(_ site: MPSite) {
            DispatchQueue.main.perform {
                self.nameLabel.attributedText = self.result?.attributedKey
            }
            self.update()
        }

        // MARK: --- Private ---

        private func update() {
            DispatchQueue.mpw.promise { () -> Promise<String?> in
                guard let site = self.site
                else { return Promise( .success( nil ) ) }

                switch self.mode {
                    case .authentication:
                        return site.mpw_result()
                    case .identification:
                        return site.mpw_login()
                    case .recovery:
                        return site.mpw_answer()
                    @unknown default:
                        return Promise( .success( nil ) )
                }
            }.then( on: DispatchQueue.main ) { (result: String?) in
                self.modeButton.title = self.mode.button()
                self.modeButton.size = .small
                self.resultLabel.text = result
            }
        }
    }

    class LiefsteCell: UITableViewCell {
        private let emitterView = MPEmitterView()
        private let propLabel   = UILabel()
        private var player: AVPlayer?

        class func `is`(result: MPQuery.Result<MPSite>?) -> Bool {
            result?.value.siteName == "liefste"
        }

        // MARK: --- Life ---

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init( style: style, reuseIdentifier: reuseIdentifier )

            // - View
            self.isOpaque = false
            self.clipsToBounds = true
            self.backgroundColor = .clear
            self.selectedBackgroundView = UIView()
            self.selectedBackgroundView?.backgroundColor = MPTheme.global.color.selection.get()
            self.contentView.layoutMargins = UIEdgeInsets( top: 80, left: 80, bottom: 80, right: 80 )

            self.propLabel.text = "💁"
            self.propLabel.textAlignment = .center
            self.propLabel.font = MPTheme.global.font.largeTitle.get()
            self.propLabel.layer.shadowRadius = 8
            self.propLabel.layer.shadowOpacity = 0.618
            self.propLabel.layer.shadowColor = MPTheme.global.color.glow.get()?.cgColor
            self.propLabel.layer.shadowOffset = .zero

            // - Hierarchy
            self.contentView.addSubview( self.emitterView )
            self.contentView.addSubview( self.propLabel )

            // - Layout
            LayoutConfiguration( view: self.emitterView )
                    .constrainToOwner()
                    .activate()
            LayoutConfiguration( view: self.propLabel )
                    .constrainTo { $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.topAnchor ) }
                    .constrainTo { $1.leadingAnchor.constraint( greaterThanOrEqualTo: $0.layoutMarginsGuide.leadingAnchor ) }
                    .constrainTo { $1.centerXAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerXAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( lessThanOrEqualTo: $0.layoutMarginsGuide.trailingAnchor ) }
                    .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.layoutMarginsGuide.bottomAnchor ) }
                    .activate()
        }

        func willDisplay() {
            self.player = AVPlayer( url: URL( string: "https://stuff.lhunath.com/liefste.mp3" )! )
            self.player?.play()
            self.emitterView.emit( with: [
                .shape( .circle, MPTheme.global.color.selection.get() ),
                .shape( .triangle, MPTheme.global.color.shadow.get() ),
                .emoji( "🎈" ),
                .emoji( "❤️" ),
                .emoji( "🎉" )
            ], for: 8 )
            self.emitterView.emit( with: [
                .emoji( "❤️" ),
            ], for: 200 )
        }

        func didEndDisplaying() {
            self.player = nil
        }
    }
}

protocol MPSitesViewObserver {
    func siteWasSelected(selectedSite: MPSite?)
}
