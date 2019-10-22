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
            let selectedPath = self.resultSource.indexPath( where: { $0?.value == self.selectedSite } )
            if self.indexPathForSelectedRow != selectedPath {
                self.selectRow( at: selectedPath, animated: UIView.areAnimationsEnabled, scrollPosition: .middle )
            }
            else if let selectedPath = selectedPath {
                self.scrollToRow( at: selectedPath, at: .middle, animated: UIView.areAnimationsEnabled )
            }

            if self.selectedSite != oldValue {
                self.observers.notify { $0.siteWasSelected( site: self.selectedSite ) }
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
    private var isInitial = true
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
                self.selectedSite = selectedResult?.value
            }
        }
    }

    // MARK: --- UITableViewDelegate ---

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
        cell.sitesView = self
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
        public var sitesView: MPSitesTableView?
        public var result:    MPQuery.Result<MPSite>? {
            didSet {
                self.site = self.result?.value
            }
        }
        public var site:      MPSite? {
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
        public var new = false

        private var mode           = MPKeyPurpose.authentication {
            didSet {
                self.update()
            }
        }
        private let resultLabel    = UITextField()
        private let nameLabel      = UILabel()
        private let modeButton     = MPButton( image: UIImage( named: "icon_person" ) )
        private let settingsButton = MPButton( image: UIImage( named: "icon_sliders" ) )

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

            self.contentView.addGestureRecognizer( UITapGestureRecognizer( target: self, action: #selector( cellAction ) ) )

            self.selectedBackgroundView = UIView()
            self.selectedBackgroundView?.backgroundColor = MPTheme.global.color.selection.get()

            self.resultLabel.adjustsFontSizeToFitWidth = true
            self.resultLabel.font = MPTheme.global.font.password.get()?.withSize( 32 )
            self.resultLabel.text = " "
            self.resultLabel.textAlignment = .center
            self.resultLabel.textColor = MPTheme.global.color.body.get()
            self.resultLabel.isEnabled = false

            self.nameLabel.font = MPTheme.global.font.caption1.get()
            self.nameLabel.textAlignment = .center
            self.nameLabel.textColor = MPTheme.global.color.body.get()
            self.nameLabel.shadowColor = MPTheme.global.color.shadow.get()
            self.nameLabel.shadowOffset = CGSize( width: 0, height: 1 )

            self.settingsButton.button.addAction( for: .touchUpInside ) { _, _ in
                if let site = self.site {
                    self.sitesView?.observers.notify { $0.siteDetailsAction( site: site ) }
                }
            }

            self.modeButton.tapEffect = false
            self.modeButton.effectBackground = false
            self.modeButton.button.addAction( for: .touchUpInside ) { _, _ in self.modeAction() }
            self.modeButton.button.setContentCompressionResistancePriority( .defaultHigh + 1, for: .horizontal )

            // - Hierarchy
            self.contentView.addSubview( self.resultLabel )
            self.contentView.addSubview( self.nameLabel )
            self.contentView.addSubview( self.modeButton )
            self.contentView.addSubview( self.settingsButton )

            // - Layout
            LayoutConfiguration( view: self.modeButton )
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                    .constrainTo { $1.centerYAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerYAnchor ) }
                    .activate()

            LayoutConfiguration( view: self.settingsButton )
                    .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                    .constrainTo { $1.centerYAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerYAnchor ) }
                    .activate()

            LayoutConfiguration( view: self.resultLabel )
                    .constrainTo { $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.topAnchor ) }
                    .constrainTo { $1.leadingAnchor.constraint( greaterThanOrEqualTo: self.modeButton.trailingAnchor, constant: 4 ) }
                    .constrainTo { $1.centerXAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerXAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( lessThanOrEqualTo: self.settingsButton.leadingAnchor, constant: -4 ) }
                    .huggingPriorityHorizontal( .fittingSizeLevel, vertical: .defaultLow )
                    .compressionResistancePriorityHorizontal( .defaultHigh - 1, vertical: .defaultHigh + 1 )
                    .activate()

            LayoutConfiguration( view: self.nameLabel )
                    .constrainTo { $1.topAnchor.constraint( equalTo: self.resultLabel.bottomAnchor ) }
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: self.resultLabel.leadingAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( equalTo: self.resultLabel.trailingAnchor ) }
                    .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.layoutMarginsGuide.bottomAnchor ) }
                    .activate()
        }

        override func setSelected(_ selected: Bool, animated: Bool) {
            super.setSelected( selected, animated: animated )

            UIView.animate( withDuration: 0.382 ) {
                self.settingsButton.alpha = selected ? 1: 0
            }
        }

        func modeAction() {
            switch self.mode {
                case .authentication:
                    self.mode = .identification
                case .identification:
                    self.mode = .authentication
                default:
                    self.mode = .authentication
            }
        }

        @objc
        func cellAction() {
            self.sitesView?.selectedSite = self.site

            self.site?.mpw_copy( keyPurpose: self.mode, for: self ).then {
                if let site = self.site, self.new {
                    site.user.sites.append( site )
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
            self.site?.mpw_result( keyPurpose: self.mode ).then( on: DispatchQueue.main ) { (result: String?) in
                switch self.mode {
                    case .authentication:
                        self.modeButton.image = UIImage( named: "icon_tripledot" )
                    case .identification:
                        self.modeButton.image = UIImage( named: "icon_user" )
                    case .recovery:
                        self.modeButton.image = UIImage( named: "icon_btn_question" )
                    @unknown default:
                        self.modeButton.image = nil
                }
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
    func siteWasSelected(site selectedSite: MPSite?)
    func siteDetailsAction(site: MPSite)
}
