//
// Created by Maarten Billemont on 2018-03-25.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit
import AVKit

class SitesTableView: UITableView, UITableViewDelegate, UserObserver, Updatable {
    public var user:            User? {
        willSet {
            self.user?.observers.unregister( observer: self )
            self.query = nil
        }
        didSet {
            self.user?.observers.register( observer: self )
            self.updateTask.request()
        }
    }
    public var query:           String? {
        didSet {
            if oldValue != self.query {
                self.updateTask.request()
            }
        }
    }
    public var siteActions = [ SiteAction ]() {
        didSet {
            self.updateTask.request()
        }
    }
    public var preferredFilter: ((Site) -> Bool)? {
        didSet {
            self.updateTask.request()
        }
    }
    public var preferredSite:   String?

    private lazy var sitesDataSource = SitesSource( view: self )

    // MARK: --- State ---

    override var contentSize:          CGSize {
        didSet {
            self.invalidateIntrinsicContentSize()
        }
    }
    override var intrinsicContentSize: CGSize {
        CGSize( width: UIView.noIntrinsicMetric, height: max( 1, self.contentSize.height ) )
    }

    // MARK: --- Life ---

    init() {
        super.init( frame: .zero, style: .plain )

        self.register( SiteCell.self )
        self.register( LiefsteCell.self )

        self.delegate = self
        self.dataSource = self.sitesDataSource
        self.backgroundColor = .clear
        self.isOpaque = false
        self.separatorStyle = .none
        self => \.separatorColor => Theme.current.color.mute
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    // MARK: --- Internal ---

    var updatesPostponed: Bool {
        // Updates prior to attachment may result in an incorrect initial content offset.
        DispatchQueue.main.await { self.window == nil }
    }

    lazy var updateTask = DispatchTask.update( self, deadline: .now() + .milliseconds( 100 ) ) { [weak self] in
        guard let self = self
        else { return }

        var elementsBySection = [ [ SiteItem ] ]()

        if let user = self.user, user.userKeyFactory != nil {
            // Filter sites by query and order by preference.
            let results = SiteItem.filtered( user.sites, query: self.query ?? "", preferred: self.preferredFilter )
            elementsBySection.append( results )

            // Add "new site" result if there is a query and no exact result
            if let query = self.query?.nonEmpty, !results.contains( where: { $0.isExact } ) {
                elementsBySection.append( [ using( self.sitesDataSource.newItem ) {
                    $0?.site.siteName = query
                    $0?.query = query
                } ??
                        using( SiteItem( site: Site( user: user, siteName: query ), query: query ) ) {
                            self.sitesDataSource.newItem = $0
                        } ] )
            }
            // Add "new site" result if there is a preferred site and no preferred results
            else if let preferredSite = self.preferredSite?.nonEmpty, !results.contains( where: { $0.isPreferred } ) {
                elementsBySection.insert( [ self.sitesDataSource.preferredItem ??
                        using( SiteItem( site: Site( user: user, siteName: preferredSite ), preferred: true ) ) {
                            self.sitesDataSource.preferredItem = $0
                        } ], at: 0 )
            }
            else {
                elementsBySection.append( [] )
                self.sitesDataSource.newItem = nil
            }

            // Special case for selected site: keep selection on the site result that matches the query
            if let selectedItem = self.sitesDataSource.selectedItem {
                if let newItem = self.sitesDataSource.newItem, selectedItem == newItem {
                    self.sitesDataSource.selectedItem = newItem
                }
                else {
                    self.sitesDataSource.selectedItem = results.first { $0.id == selectedItem.id }
                }
            }
        }

        // Update the sites table to show the newly filtered sites
        self.sitesDataSource.update( elementsBySection, selected: Set( [ self.sitesDataSource.selectedItem ] ) )
    }

    // MARK: --- UITableViewDelegate ---

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        (cell as? LiefsteCell)?.willDisplay()

        #if TARGET_APP
        (cell as? SiteCell)?.site?.refresh()
        #endif
    }

    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        (cell as? LiefsteCell)?.didEndDisplaying()
    }

    @available( iOS 13, * )
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        (self.sitesDataSource.element( at: indexPath )?.site).flatMap { site in
            UIContextMenuConfiguration(
                    indexPath: indexPath, previewProvider: { _ in SitePreviewController( site: site ) },
                    actionProvider: { [unowned self] _, configuration in
                        UIMenu( title: site.siteName, children: [
                            UIAction( title: "Delete", image: .icon( "" ),
                                      identifier: UIAction.Identifier( "delete" ), attributes: .destructive ) { action in
                                configuration.action = action
                                site.user.sites.removeAll { $0 === site }
                            }
                        ] + self.siteActions.filter( { $0.appearance.contains( .menu ) } ).map { siteAction in
                            UIAction( title: siteAction.title, image: .icon( siteAction.icon ),
                                      identifier: siteAction.tracking.flatMap { UIAction.Identifier( $0.action ) } ) { action in
                                configuration.action = action
                                siteAction.action( site, nil, .menu )
                            }
                        } )
                    } )
        }
    }

    @available( iOS 13, * )
    func tableView(_ tableView: UITableView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let indexPath = configuration.indexPath, let view = self.cellForRow( at: indexPath )
        else { return nil }

        configuration.event = Tracker.shared.begin( track: .subject( "sites.site", action: "menu" ) )

        let parameters = UIPreviewParameters()
        parameters.backgroundColor = self.sitesDataSource.element( at: indexPath )?.site.preview.color?.with( alpha: .long )
        return UITargetedPreview( view: view, parameters: parameters )
    }

    @available( iOS 13, * )
    func tableView(_ tableView: UITableView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let indexPath = configuration.indexPath, let view = self.cellForRow( at: indexPath )
        else { return nil }

        configuration.event?.end( [ "action": configuration.action?.identifier.rawValue ?? "none" ] )

        let parameters = UIPreviewParameters()
        parameters.backgroundColor = self.sitesDataSource.element( at: indexPath )?.site.preview.color?.with( alpha: .long )
        return UITargetedPreview( view: view, parameters: parameters )
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.sitesDataSource.selectedItem = self.sitesDataSource.element( at: self.indexPathForSelectedRow )
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        self.sitesDataSource.selectedItem = self.sitesDataSource.element( at: self.indexPathForSelectedRow )
    }

    // MARK: --- UserObserver ---

    func userDidLogin(_ user: User) {
        self.updateTask.request()
    }

    func userDidLogout(_ user: User) {
        self.updateTask.request()
    }

    func userDidChange(_ user: User) {
        self.updateTask.request()
    }

    func userDidUpdateSites(_ user: User) {
        self.updateTask.request()
    }

    // MARK: --- Types ---

    class SiteItem: Hashable, Identifiable, Comparable, CustomDebugStringConvertible {
        class func filtered(_ sites: [Site], query: String, preferred: ((Site) -> Bool)?) -> [SiteItem] {
            var items = sites.map { SiteItem( site: $0, query: query, preferred: preferred?( $0 ) ?? false ) }
                             .filter { $0.isMatched }.sorted()

            if preferred != nil {
                items = items.reordered( first: { $0.isPreferred } )
            }

            return items
        }

        var debugDescription: String {
            "{SiteItem: id=\(self.id), isMatched=\(self.isMatched), isExact=\(self.isExact), isPreferred=\(self.isPreferred), subtitle=\(self.subtitle), site=\(self.site)}"
        }

        let site: Site
        var subtitle = NSAttributedString()
        var matches  = [ String.Index ]()
        var query    = "" {
            didSet {
                let key           = self.site.siteName
                let attributedKey = NSMutableAttributedString( string: key )
                defer { self.subtitle = NSAttributedString( attributedString: attributedKey ) }
                self.isExact = key == self.query

                if self.isExact {
                    self.matches = Array( attributedKey.string.indices )
                    self.isMatched = true
                    attributedKey.addAttribute( NSAttributedString.Key.backgroundColor, value: UIColor.red,
                                                range: NSRange( key.startIndex..<key.endIndex, in: key ) )
                    return
                }

                self.matches = [ String.Index ]()
                if key.isEmpty || self.query.isEmpty {
                    self.isMatched = self.query.isEmpty
                    return
                }

                // Consume query and key characters until one of them runs out, recording any matches against the result's key.
                var q = self.query.startIndex, k = key.startIndex, n = k
                while ((q < self.query.endIndex) && (k < key.endIndex)) {
                    n = key.index( after: k )

                    if self.query[q] == key[k] {
                        self.matches.append( k )
                        attributedKey.addAttribute( NSAttributedString.Key.backgroundColor, value: UIColor.red,
                                                    range: NSRange( k..<n, in: key ) )
                        q = self.query.index( after: q )
                    }

                    k = n
                }

                // If the match against the query broke before the end of the query, it failed.
                self.isMatched = !(q < self.query.endIndex)
            }
        }

        var isMatched = false
        var isExact   = false
        let isPreferred: Bool

        var id: String {
            self.site.siteName
        }

        init(site: Site, query: String = "", preferred: Bool = false) {
            self.site = site
            self.isPreferred = preferred

            defer {
                self.query = query
            }
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine( self.site )
        }

        static func ==(lhs: SiteItem, rhs: SiteItem) -> Bool {
            lhs.subtitle == rhs.subtitle && lhs.site === rhs.site
        }

        static func <(lhs: SiteItem, rhs: SiteItem) -> Bool {
            lhs.site < rhs.site
        }
    }

    class SitesSource: DataSource<SiteItem> {
        unowned let view: SitesTableView
        var newItem:       SiteItem?
        var preferredItem: SiteItem?
        var selectedItem:  SiteItem?

        init(view: SitesTableView) {
            self.view = view

            super.init( tableView: view )
        }

        override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
            !(self.element( at: indexPath )?.site.isNew ?? true)
        }

        override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
            if let site = self.element( at: indexPath )?.site, editingStyle == .delete {
                Tracker.shared.event( track: .subject( "sites.site", action: "delete" ) )

                site.user.sites.removeAll { $0 === site }
            }
        }

        override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let result = self.element( at: indexPath )
            if LiefsteCell.is( result: result ) {
                return LiefsteCell.dequeue( from: tableView, indexPath: indexPath )
            }

            let cell = SiteCell.dequeue( from: tableView, indexPath: indexPath )
            cell.sitesView = self.view
            cell.result = result
            cell.updateTask.request(immediate: true)
            return cell
        }
    }

    class SiteCell: UITableViewCell, Updatable, SiteObserver, UserObserver, AppConfigObserver, InAppFeatureObserver {
        public weak var sitesView: SitesTableView?
        public var result: SiteItem? {
            willSet {
                self.site?.observers.unregister( observer: self )
                self.site?.user.observers.unregister( observer: self )
            }
            didSet {
                if let site = self.site {
                    site.observers.register( observer: self )
                    site.user.observers.register( observer: self )
                }

                self.updateTask.request()
            }
        }
        public var site:   Site? {
            self.result?.site
        }

        private var mode            = SpectreKeyPurpose.authentication {
            didSet {
                if oldValue != self.mode {
                    self.updateTask.request()
                }
            }
        }
        private let backgroundImage = BackgroundView( mode: .clear )
        private let modeButton      = EffectButton( track: .subject( "sites.site", action: "mode" ),
                                                    image: .icon( "" ), border: 0, background: false )
        private let newButton       = EffectButton( track: .subject( "sites.site", action: "add" ),
                                                    image: .icon( "" ), border: 0, background: false )
        private let actionsStack    = UIStackView()
        private let selectionView   = UIView()
        private let resultLabel     = UITextField()
        private let captionLabel    = UILabel()
        private lazy var contentStack = UIStackView( arrangedSubviews: [ self.selectionView, self.resultLabel, self.captionLabel ] )
        private lazy var selectionConfiguration = LayoutConfiguration( view: self.contentStack ) { active, inactive in
            active.constrain {
                $1.heightAnchor.constraint( equalTo: $0.widthAnchor, multiplier: .short )
                               .with( priority: .defaultHigh + 10 )
            }
        }.needs( .update )

        // MARK: --- Life ---

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init( style: style, reuseIdentifier: reuseIdentifier )

            // - View
            self.isOpaque = false
            self.clipsToBounds = true

            self.selectedBackgroundView = self.backgroundImage

            self.contentView.insetsLayoutMarginsFromSafeArea = false

            self.contentStack.axis = .vertical

            self.actionsStack.axis = .vertical
            self.actionsStack.distribution = .fillEqually

            self.resultLabel.adjustsFontSizeToFitWidth = true
            self.resultLabel => \.font => Theme.current.font.password.transform { $0?.withSize( 32 ) }
            self.resultLabel.text = " "
            self.resultLabel.textAlignment = .center
            self.resultLabel => \.textColor => Theme.current.color.body
            self.resultLabel.isEnabled = false

            self.captionLabel => \.font => Theme.current.font.caption1
            self.captionLabel.textAlignment = .center
            self.captionLabel => \.textColor => Theme.current.color.secondary
            self.captionLabel => \.shadowColor => Theme.current.color.shadow
            self.captionLabel.shadowOffset = CGSize( width: 0, height: 1 )

            self.newButton.tapEffect = false
            self.newButton.isUserInteractionEnabled = false
            self.newButton.action( for: .primaryActionTriggered ) { [unowned self] in
                if let site = self.site, site.isNew {
                    site.user.sites.append( site )
                }
            }

            self.modeButton.tapEffect = false
            self.modeButton.action( for: .primaryActionTriggered ) { [unowned self] in
                switch self.mode {
                    case .authentication:
                        self.mode = .identification
                    case .identification:
                        self.mode = .authentication
                    default:
                        self.mode = .authentication
                }
            }

            // - Hierarchy
            self.contentView.addSubview( self.contentStack )
            self.contentView.addSubview( self.modeButton )
            self.contentView.addSubview( self.actionsStack )
            self.contentView.addSubview( self.newButton )

            // - Layout
            LayoutConfiguration( view: self.modeButton )
                    .constrain { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                    .constrain { $1.topAnchor.constraint( greaterThanOrEqualTo: $0.topAnchor ) }
                    .constrain { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.bottomAnchor ) }
                    .constrain { $1.centerYAnchor.constraint( equalTo: self.resultLabel.centerYAnchor ) }
                    .activate()

            LayoutConfiguration( view: self.actionsStack )
                    .constrain { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                    .constrain { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                    .constrain { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                    .activate()

            LayoutConfiguration( view: self.newButton )
                    .constrain { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                    .constrain { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                    .constrain { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                    .activate()

            LayoutConfiguration( view: self.contentStack )
                    .constrain { $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.topAnchor ) }
                    .constrain { $1.leadingAnchor.constraint( greaterThanOrEqualTo: self.modeButton.trailingAnchor ) }
                    .constrain { $1.centerXAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerXAnchor ) }
                    .constrain { $1.trailingAnchor.constraint( lessThanOrEqualTo: self.actionsStack.leadingAnchor ) }
                    .constrain { $1.trailingAnchor.constraint( lessThanOrEqualTo: self.newButton.leadingAnchor ) }
                    .constrain { $1.bottomAnchor.constraint( equalTo: $0.layoutMarginsGuide.bottomAnchor ) }
                    .activate()

            LayoutConfiguration( view: self.selectionView )
                    .hugging( horizontal: .fittingSizeLevel, vertical: .fittingSizeLevel )
                    .activate()

            LayoutConfiguration( view: self.resultLabel )
                    .hugging( horizontal: .fittingSizeLevel, vertical: .defaultLow )
                    .compressionResistance( horizontal: .defaultHigh - 1, vertical: .defaultHigh + 3 )
                    .activate()

            LayoutConfiguration( view: self.captionLabel )
                    .hugging( horizontal: .fittingSizeLevel, vertical: .defaultLow )
                    .compressionResistance( horizontal: .defaultHigh - 1, vertical: .defaultHigh + 2 )
                    .activate()
        }

        override func willMove(toWindow newWindow: UIWindow?) {
            super.willMove( toWindow: newWindow )

            if newWindow != nil {
                AppConfig.shared.observers.register( observer: self )
                InAppFeature.observers.register( observer: self )
            }
            else {
                AppConfig.shared.observers.unregister( observer: self )
                InAppFeature.observers.unregister( observer: self )
            }
        }

        override func didMoveToSuperview() {
            super.didMoveToSuperview()

            self.actionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            self.sitesView?.siteActions.filter( { $0.appearance.contains( .cell ) } ).forEach { action in
                self.actionsStack.addArrangedSubview(
                        EffectButton( track: action.tracking, image: .icon( action.icon ), border: 0, background: false ) {
                            [unowned self] _, _ in
                            if let site = self.site {
                                action.action( site, self.mode, .cell )
                            }
                        } )
            }
        }

        override var isSelected: Bool {
            didSet {
                if oldValue != self.isSelected {
                    self.updateTask.request()
                }
            }
        }

        override func setSelected(_ selected: Bool, animated: Bool) {
            if self.isSelected != selected {
                super.setSelected( selected, animated: animated )
                self.updateTask.request()
            }
        }

        // MARK: --- UserObserver ---

        func userDidChange(_ user: User) {
            self.updateTask.request()
        }

        // MARK: --- SiteObserver ---

        func siteDidChange(_ site: Site) {
            self.updateTask.request()
        }

        // MARK: --- AppConfigObserver ---

        func didChangeConfig() {
            self.updateTask.request()
        }

        // MARK: --- InAppFeatureObserver ---

        func featureDidChange(_ feature: InAppFeature) {
            self.updateTask.request()
        }

        // MARK: --- Private ---

        lazy var updateTask = DispatchTask.update( self ) { [weak self] in
            guard let self = self
            else { return }

            self => \.backgroundColor => ((self.result?.isPreferred ?? false) ? Theme.current.color.shadow: Theme.current.color.backdrop)

            self.backgroundImage.mode = .custom( color: Theme.current.color.panel.get()?.with( hue: self.site?.preview.color?.hue ) )
            self.backgroundImage.image = self.site?.preview.image
            self.backgroundImage.imageColor = self.site?.preview.color

            let isNew = self.site?.isNew ?? false
            if let resultCaption = self.result.flatMap( { NSMutableAttributedString( attributedString: $0.subtitle ) } ) {
                if isNew {
                    resultCaption.append( NSAttributedString( string: " (new site)" ) )
                }
                self.captionLabel.attributedText = resultCaption
            }
            else {
                self.captionLabel.attributedText = nil
            }

            if !InAppFeature.premium.isEnabled {
                self.mode = .authentication
            }
            switch self.mode {
                case .authentication:
                    self.modeButton.image = .icon( "" )
                case .identification:
                    self.modeButton.image = .icon( "" )
                case .recovery:
                    self.modeButton.image = .icon( "" )
                @unknown default:
                    self.modeButton.image = nil
            }

            self.modeButton.alpha = InAppFeature.premium.isEnabled ? .on: .off
            self.modeButton.isUserInteractionEnabled = self.modeButton.alpha != .off
            self.actionsStack.alpha = self.isSelected && !isNew ? .on: .off
            self.actionsStack.isUserInteractionEnabled = self.actionsStack.alpha != .off
            self.newButton.alpha = self.isSelected && isNew ? .on: .off
            self.newButton.isUserInteractionEnabled = self.newButton.alpha != .off
            self.selectionConfiguration.isActive = self.isSelected
            self.resultLabel.isSecureTextEntry = self.mode == .authentication && self.site?.user.maskPasswords ?? true

            self.site?.result( keyPurpose: self.mode ).token.then( on: .main ) {
                do {
                    self.resultLabel.text = try $0.get()
                }
                catch {
                    mperror( title: "Couldn't update site cell.", error: error )
                }
            }
        }
    }

    class LiefsteCell: UITableViewCell {
        private let emitterView = EmitterView()
        private let propLabel   = UILabel()
        private var player: AVPlayer?

        class func `is`(result: SiteItem?) -> Bool {
            result?.site.siteName == "liefste"
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
            self.selectedBackgroundView! => \.backgroundColor => Theme.current.color.selection
            self.contentView.layoutMargins = .border( 80 )

            self.propLabel.text = "💁"
            self.propLabel.textAlignment = .center
            self.propLabel => \.font => Theme.current.font.largeTitle
            self.propLabel.layer.shadowRadius = 8
            self.propLabel.layer.shadowOpacity = .long
            self.propLabel.layer.shadowOffset = .zero
            self.propLabel.layer => \.shadowColor => Theme.current.color.shadow

            // - Hierarchy
            self.contentView.addSubview( self.emitterView )
            self.contentView.addSubview( self.propLabel )

            // - Layout
            LayoutConfiguration( view: self.emitterView )
                    .constrain( as: .box ).activate()
            LayoutConfiguration( view: self.propLabel )
                    .constrain { $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.topAnchor ) }
                    .constrain { $1.leadingAnchor.constraint( greaterThanOrEqualTo: $0.layoutMarginsGuide.leadingAnchor ) }
                    .constrain { $1.centerXAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerXAnchor ) }
                    .constrain { $1.trailingAnchor.constraint( lessThanOrEqualTo: $0.layoutMarginsGuide.trailingAnchor ) }
                    .constrain { $1.bottomAnchor.constraint( equalTo: $0.layoutMarginsGuide.bottomAnchor ) }
                    .activate()
        }

        func willDisplay() {
            Tracker.shared.event( track: .subject( "sites", action: "liefste" ) )

            self.player = AVPlayer( url: URL( string: "https://stuff.lhunath.com/liefste.mp3" )! )
            self.player?.play()
            self.emitterView.emit( with: [
                .shape( .circle, Theme.current.color.selection.get() ),
                .shape( .triangle, Theme.current.color.shadow.get() ),
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

    struct SiteAction {
        let tracking:   Tracking?
        let title:      String
        let icon:       String
        let appearance: [Appearance]
        let action:     (Site, SpectreKeyPurpose?, Appearance) -> Void

        enum Appearance {
            case cell, menu
        }
    }
}
