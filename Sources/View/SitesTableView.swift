// =============================================================================
// Created by Maarten Billemont on 2018-03-25.
// Copyright (c) 2018 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import UIKit
import AVKit
import OrderedCollections

// swiftlint:disable:next type_body_length
class SitesTableView: UITableView, UITableViewDelegate, UserObserver, Updatable {
    public var user:            User? {
        didSet {
            if oldValue != self.user {
                oldValue?.observers.unregister( observer: self )
                self.user?.observers.register( observer: self )
                self.query = nil
                self.updateTask.request()
            }
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
    public var proposedSite:    String?

    // MARK: - State

    override var contentSize:          CGSize {
        didSet {
            self.invalidateIntrinsicContentSize()
        }
    }
    override var intrinsicContentSize: CGSize {
        CGSize( width: UIView.noIntrinsicMetric, height: max( 1, self.contentSize.height ) )
    }

    // MARK: - Life

    private var sitesDataSource: DataSource<Sections, SiteItem>!

    init() {
        super.init( frame: .zero, style: .plain )
        LeakRegistry.shared.register( self )

        self.register( SiteCell.self )

        self.sitesDataSource = .init( tableView: self ) { tableView, indexPath, item in
            SiteCell.dequeue( from: tableView, indexPath: indexPath ) { (cell: SiteCell) in
                cell.sitesView = tableView as? SitesTableView
                cell.result = item
                cell.updateTask.request( now: true )
            }
        } editor: { item in
            guard !item.isNew
            else { return nil }

            return { editingStyle in
                if editingStyle == .delete {
                    Tracker.shared.event( track: .subject( "sites.site", action: "delete" ) )
                    item.site.user?.sites.removeAll { $0 === item.site }
                }
            }
        }

        self.delegate = self
        self.backgroundColor = .clear
        self.backgroundView = UIView()
        self.separatorStyle = .none
        self => \.separatorColor => Theme.current.color.mute
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override func didMoveToWindow() {
        if self.window != nil {
            self.updateTask.request( now: true )
        }

        super.didMoveToWindow()
    }

    // MARK: - Internal

    var updatesRejected: Bool {
        // Updates prior to attachment may result in an incorrect initial content offset.
        DispatchQueue.main.await { self.window == nil }
    }

    lazy var updateTask = DispatchTask.update( self ) { [weak self] in
        guard let self = self
        else { return }

        var sites = NSDiffableDataSourceSnapshot<Sections, SiteItem>()

        var selectionOptions = [ SiteItem ]()
        sites.appendSections( Sections.allCases )

        if let user = self.user, user.userKeyFactory != nil {
            // Filter sites by query and order by preference.
            let results = SiteItem.filtered( user.sites, query: self.query ?? "", preferred: self.preferredFilter ?? { _ in false } )

            // Add "new site" from proposed site if there is one and no preferred results
            if let proposedSite = self.proposedSite?.nonEmpty, !results.contains( where: { $0.isPreferred } ) {
                let proposedItem = SiteItem( site: Site( user: user, siteName: proposedSite ), preferred: true, new: true )
                sites.appendItems( [ proposedItem ], toSection: .proposed )
                selectionOptions.append( proposedItem )
            }

            // Section 0: Known site results.
            sites.appendItems( OrderedSet( results ).elements, toSection: .known )
            results.first.flatMap { selectionOptions.append( $0 ) }

            // Section 1: New site from query.
            if let query = self.query?.nonEmpty,
               !results.contains( where: { $0.isExact } ),
               !selectionOptions.contains( where: { $0.site.siteName == query } ) {
                let newItem = SiteItem( site: Site( user: user, siteName: query ), query: query, preferred: false, new: true )
                sites.appendItems( [ newItem ], toSection: .new )
                selectionOptions.append( newItem )
            }
        }

        // Reload items that already exist but have changed.
        let updatedItems = sites.itemIdentifiers.joinedIntersection( self.sitesDataSource.snapshot()?.itemIdentifiers ?? [] )
                                .compactMap { new, old in new.isEqual( to: old ) ? nil : new }

        // Update the sites table to show the newly filtered sites
        let selectedItems = self.sitesDataSource.selectedItems
        self.sitesDataSource.apply( sites ) {

            // Reconfigure *after* applying new sites due to an iOS bug: unchanged item identifiers only updated after snapshot is applied.
            if #available( iOS 15.0, * ) {
                sites.reconfigureItems( updatedItems )
            }
            else {
                sites.reloadItems( updatedItems )
            }

            self.sitesDataSource.apply( sites, animatingDifferences: false ) {
                for selectItem in selectedItems + selectionOptions {
                    if let selectItem = sites.itemIdentifiers.first( where: { $0 == selectItem } ) {
                        self.sitesDataSource.select( item: selectItem )
                        break
                    }
                }
            }
        }
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        (cell as? CellAppearance)?.willDisplay()
    }

    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        (cell as? CellAppearance)?.didEndDisplaying()
    }

    private var previewEvents = [ IndexPath: Tracker.TimedEvent ]()

    #if TARGET_APP
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint)
            -> UIContextMenuConfiguration? {
        (self.sitesDataSource.item( for: indexPath )?.site).flatMap { site in
            UIContextMenuConfiguration(
                    indexPath: indexPath, previewProvider: { _ in SitePreviewController( site: site ) },
                    actionProvider: { [unowned self] _, _ in
                        UIMenu( title: site.siteName, children:
                        .init( arrayLiteral: UIAction( title: "Delete", image: .icon( "trash-can" ),
                                                       identifier: UIAction.Identifier( "delete" ), attributes: .destructive,
                                                       handler: { _ in site.user?.sites.removeAll { $0 === site } } ) )
                        + self.siteActions
                              .filter { siteAction in
                                  if !siteAction.appearance.contains( .menu ) {
                                      // Not a menu action.
                                      return false
                                  }
                                  if siteAction.appearance.contains( where: {
                                      if case let .feature(feature) = $0 { return !feature.isEnabled }
                                      return false
                                  } ) {
                                      // Required feature is missing.
                                      return false
                                  }
                                  return true
                              }
                              .map { siteAction in
                                  UIAction( title: siteAction.title, image: .icon( siteAction.icon ) ) { action in
                                      if let tracking = siteAction.tracking {
                                          self.previewEvents[indexPath]?.end( [ "action": tracking.action ] )
                                          Tracker.shared.event( track: tracking.with( parameters: [
                                              "appearance": "menu",
                                          ] ) )
                                      }

                                      siteAction.action( site, nil, .menu )
                                  }
                              } )
                    } )
        }
    }

    func tableView(_ tableView: UITableView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration)
            -> UITargetedPreview? {
        guard let indexPath = configuration.indexPath, let view = self.cellForRow( at: indexPath )
        else { return nil }

        self.previewEvents[indexPath] = Tracker.shared.begin( track: .subject( "sites.site", action: "menu" ) )

        let parameters = UIPreviewParameters()
        parameters.backgroundColor = self.sitesDataSource.item( for: indexPath )?.site.preview.color?.with( alpha: .long )
        return UITargetedPreview( view: view, parameters: parameters )
    }

    func tableView(_ tableView: UITableView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration)
            -> UITargetedPreview? {
        guard let indexPath = configuration.indexPath, let view = self.cellForRow( at: indexPath )
        else { return nil }

        self.previewEvents[indexPath]?.end( [ "action": "none" ] )

        let parameters = UIPreviewParameters()
        parameters.backgroundColor = self.sitesDataSource.item( for: indexPath )?.site.preview.color?.with( alpha: .long )
        return UITargetedPreview( view: view, parameters: parameters )
    }
    #endif

    // MARK: - UserObserver

    func didLogin(user: User) {
        self.updateTask.request()
    }

    func didLogout(user: User) {
        self.updateTask.request()
    }

    func didChange(user: User, at change: PartialKeyPath<User>) {
        self.updateTask.request()
    }

    func didUpdateSites(user: User) {
        self.updateTask.request()
    }

    // MARK: - Types

    struct SiteItem: Hashable, Identifiable, Comparable, CustomDebugStringConvertible {
        static func filtered(_ sites: [Site], query: String, preferred: (Site) -> Bool) -> [SiteItem] {
            sites.map { SiteItem( site: $0, query: query, preferred: preferred( $0 ), new: false ) }
                             .filter { $0.isMatched }.sorted()
                             .reordered( first: { $0.isPreferred } )
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
                    attributedKey.addAttribute( NSAttributedString.Key.backgroundColor,
                                                value: Theme.current.color.selection.get(forTraits: .current) as Any,
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
                while (q < self.query.endIndex) && (k < key.endIndex) {
                    n = key.index( after: k )

                    if self.query[q] == key[k] {
                        self.matches.append( k )
                        attributedKey.addAttribute( NSAttributedString.Key.backgroundColor,
                                                    value: Theme.current.color.selection.get(forTraits: .current) as Any,
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
        let isNew:       Bool

        var id: String {
            self.isNew ? "" : self.site.siteName
        }

        init(site: Site, query: String = "", preferred: Bool, new: Bool) {
            self.site = site
            self.isPreferred = preferred
            self.isNew = new

            defer {
                self.query = query
            }
        }

        func isEqual(to item: SiteItem) -> Bool {
            self.site === item.site && self.query == item.query && self.isPreferred == item.isPreferred
        }

        // MARK: - Hashable

        static func == (lhs: SiteItem, rhs: SiteItem) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine( self.id )
        }

        // MARK: - Comparable

        static func < (lhs: SiteItem, rhs: SiteItem) -> Bool {
            lhs.site < rhs.site
        }
    }

    enum Sections: Hashable, CaseIterable {
        case proposed, known, new
    }

    class SiteCell: UITableViewCell, CellAppearance, Updatable, SiteObserver, UserObserver,
                    ThemeObserver, AppConfigObserver, InAppFeatureObserver {
        public weak var sitesView: SitesTableView?
        public var result: SiteItem? {
            didSet {
                if oldValue?.site != self.result?.site {
                    oldValue?.site.user?.observers.unregister( observer: self )
                    oldValue?.site.observers.unregister( observer: self )
                    self.result?.site.observers.register( observer: self )
                    self.result?.site.user?.observers.register( observer: self )
                }

                self.updateTask.request()
            }
        }
        public var site:   Site? {
            self.result?.site
        }

        private var unmasked = false {
            didSet {
                if oldValue != self.unmasked {
                    self.updateTask.request()
                }
            }
        }
        private var purpose  = SpectreKeyPurpose.authentication {
            didSet {
                if oldValue != self.purpose {
                    self.updateTask.request()
                }
            }
        }

        private var backgroundImage: BackgroundView?
        private let maskButton      = EffectButton( track: .subject( "sites.site", action: "mask" ),
                                                    image: .icon( "eye-slash" ), border: 0, background: false )
        private let purposeButton   = EffectButton( track: .subject( "sites.site", action: "purpose" ),
                                                    image: .icon( "key" ), border: 0, background: false )
        private let newButton       = EffectButton( track: .subject( "sites.site", action: "add" ),
                                                    image: .icon( "octagon-plus" ), border: 0, background: false )

        private let actionStack   = UIStackView()
        private let selectionView = UIView()
        private let resultLabel   = UITextField()
        private let nameLabel     = UILabel()
        private let separatorView = UIView()

        private lazy var modeStack    = UIStackView( arrangedSubviews: [ self.maskButton, self.purposeButton ] )
        private lazy var contentStack = UIStackView( arrangedSubviews: [ self.selectionView, self.resultLabel, self.nameLabel ] )

        private var selectionConfiguration:   LayoutConfiguration<SiteCell>!
        private var primaryGestureRecognizer: UIGestureRecognizer? {
            didSet {
                if let oldValue = oldValue {
                    self.removeGestureRecognizer( oldValue )
                }
                if let primaryGestureRecognizer = self.primaryGestureRecognizer {
                    self.addGestureRecognizer( primaryGestureRecognizer )
                }
            }
        }

        // MARK: - Life

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        // swiftlint:disable:next function_body_length
        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init( style: style, reuseIdentifier: reuseIdentifier )
            LeakRegistry.shared.register( self )

            // - View
            self.clipsToBounds = true
            self.selectedBackgroundView = UIView()
            self.backgroundImage = BackgroundView( mode: .clear )
            self.backgroundView = self.backgroundImage

            self.contentView.insetsLayoutMarginsFromSafeArea = false

            self.contentStack.axis = .vertical

            self.modeStack.axis = .vertical
            self.modeStack.distribution = .fillEqually

            self.actionStack.axis = .vertical
            self.actionStack.distribution = .fillEqually

            self.resultLabel.adjustsFontSizeToFitWidth = true
            self.resultLabel => \.font => Theme.current.font.password.transform { $0?.withSize( 32 ) }
            self.resultLabel.text = " "
            self.resultLabel.textAlignment = .center
            self.resultLabel => \.textColor => Theme.current.color.body
            self.resultLabel.isEnabled = false

            self.nameLabel.textAlignment = .center
            self.nameLabel => \.textColor => Theme.current.color.secondary
            self.nameLabel => \.shadowColor => Theme.current.color.shadow
            self.nameLabel.shadowOffset = CGSize( width: 0, height: 1 )

            self.newButton.tapEffect = false
            self.newButton.isUserInteractionEnabled = false
            self.newButton.action( for: .primaryActionTriggered ) { [unowned self] in
                if self.result?.isNew ?? false, let site = self.site {
                    site.user?.sites.append( site )

                    #if TARGET_APP
                    self.site?.refresh()
                    #endif
                }
            }

            self.maskButton.tapEffect = false
            self.maskButton.action( for: .primaryActionTriggered ) { [unowned self] in
                self.unmasked = !self.unmasked
            }

            self.purposeButton.tapEffect = false
            self.purposeButton.action( for: .primaryActionTriggered ) { [unowned self] in
                switch self.purpose {
                    case .authentication:
                        self.purpose = .identification
                    case .identification:
                        self.purpose = .recovery
                    case .recovery:
                        self.purpose = .authentication
                    @unknown default:
                        self.purpose = .authentication
                }
            }
            self.purposeButton.addGestureRecognizer( UILongPressGestureRecognizer { [unowned self] in
                guard let site = self.site, case .began = $0.state
                else { return }

                self.sitesView?.siteActions
                    .filter { siteAction in
                        if !siteAction.appearance.contains( .mode ) {
                            // Not a mode action.
                            return false
                        }
                        if siteAction.appearance.contains( where: {
                            if case let .feature(feature) = $0 { return !feature.isEnabled }
                            return false
                        } ) {
                            // Required feature is missing.
                            return false
                        }
                        return true
                    }
                    .forEach { siteAction in
                        if let tracking = siteAction.tracking {
                            Tracker.shared.event( track: tracking.with( parameters: [
                                "purpose": self.purpose,
                                "appearance": "mode",
                            ] ) )
                        }
                        siteAction.action( site, self.purpose, .mode )
                    }
            } )

            // - Hierarchy
            self.contentView.addSubview( self.separatorView )
            self.contentView.addSubview( self.contentStack )
            self.contentView.addSubview( self.modeStack )
            self.contentView.addSubview( self.actionStack )
            self.contentView.addSubview( self.newButton )

            // - Layout
            LayoutConfiguration( view: self.separatorView )
                .constrain { $1.centerXAnchor.constraint( equalTo: $0.centerXAnchor ) }
                .constrain { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                .constrain { $1.widthAnchor.constraint( equalToConstant: 40 ).with( priority: .defaultHigh ) }
                .constrain { $1.heightAnchor.constraint( equalToConstant: 1 ) }
                .activate()

            LayoutConfiguration( view: self.modeStack )
                .constrain { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                .constrain { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                .constrain { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                .activate()

            LayoutConfiguration( view: self.actionStack )
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
                .constrain { $1.leadingAnchor.constraint( greaterThanOrEqualTo: self.modeStack.trailingAnchor ) }
                .constrain { $1.centerXAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerXAnchor ) }
                .constrain { $1.trailingAnchor.constraint( lessThanOrEqualTo: self.actionStack.leadingAnchor ) }
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

            LayoutConfiguration( view: self.nameLabel )
                .hugging( horizontal: .fittingSizeLevel, vertical: .defaultLow )
                .compressionResistance( horizontal: .defaultHigh - 1, vertical: .defaultHigh + 2 )
                .activate()

            self.selectionConfiguration = LayoutConfiguration( view: self )
                .apply( LayoutConfiguration( view: self.contentStack ) { active, _ in
                    active.constrain {
                        $1.heightAnchor.constraint( equalTo: $0.widthAnchor, multiplier: .short )
                          .with( priority: .defaultHigh + 10 )
                    }
                } )
                .apply( LayoutConfiguration( view: self.separatorView ) { active, _ in
                    active.constrain { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                    active.constrain { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                } )
                .didSet { siteCell, _ in
                    guard let dataSource = siteCell.sitesView?.sitesDataSource, var snapshot = dataSource.snapshot(),
                          let result = siteCell.result, snapshot.indexOfItem( result ) != nil
                    else { return }

                    if #available( iOS 15.0, * ) {
                        snapshot.reconfigureItems( [ result ] )
                    }
                    else {
                        snapshot.reloadItems( [ result ] )
                    }
                    dataSource.apply( snapshot )
                }
        }

        override func willMove(toWindow newWindow: UIWindow?) {
            super.willMove( toWindow: newWindow )

            if newWindow != nil {
                Theme.current.observers.register( observer: self )
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

            self.primaryGestureRecognizer = nil
            self.actionStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            self.sitesView?.siteActions
                .filter { siteAction in
                    if !siteAction.appearance.contains( .cell ) {
                        // Not a menu action.
                        return false
                    }
                    if siteAction.appearance.contains( where: {
                        if case let .feature(feature) = $0 { return !feature.isEnabled }
                        return false
                    } ) {
                        // Required feature is missing.
                        return false
                    }
                    return true
                }
                .forEach { siteAction in
                    let actionButton = EffectButton( track: siteAction.tracking?.with( parameters: [ "appearance": "cell" ] ),
                                                     image: .icon( siteAction.icon ), border: 0, background: false ) { [unowned self] in
                        if let site = self.site {
                            siteAction.action( site, self.purpose, .cell )
                        }
                    }
                    if siteAction.appearance.contains( .primary ) {
                        self.primaryGestureRecognizer = UITapGestureRecognizer { [unowned self] _ in
                            if self.newButton.isUserInteractionEnabled {
                                self.newButton.activate()
                            }
                            else {
                                actionButton.activate()
                            }
                        }
                    }
                    self.primaryGestureRecognizer?.isEnabled = self.isSelected
                    self.actionStack.addArrangedSubview( actionButton )
                }
        }

        override func prepareForReuse() {
            super.prepareForReuse()

            self.unmasked = false
            self.purpose = .authentication
            self.backgroundImage?.image = nil
        }

        func willDisplay() {
            #if TARGET_APP
            self.site?.refresh()
            #endif
        }

        func didEndDisplaying() {
            if self.backgroundImage?.alpha == .off {
                self.backgroundImage?.image = nil
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
                self.updateTask.request( now: true )
            }
        }

        // MARK: - UserObserver

        func didChange(user: User, at change: PartialKeyPath<User>) {
            self.updateTask.request()
        }

        // MARK: - SiteObserver

        func didChange(site: Site, at change: PartialKeyPath<Site>) {
            self.updateTask.request()
        }

        // MARK: - ThemeObserver

        func didChange(theme: Theme) {
            self.updateTask.request()
        }

        // MARK: - AppConfigObserver

        func didChange(appConfig: AppConfig, at change: PartialKeyPath<AppConfig>) {
            self.updateTask.request()
        }

        // MARK: - InAppFeatureObserver

        func didChange(feature: InAppFeature) {
            self.updateTask.request()
        }

        // MARK: - Private

        lazy var updateTask = DispatchTask.update( self, animated: true ) { [weak self] in
            guard let self = self
            else { return }

            self => \.backgroundColor => ((self.result?.isPreferred ?? false) ? Theme.current.color.shadow : Theme.current.color.backdrop)
            if AppConfig.shared.colorfulSites, let siteColor = self.site?.preview.color {
                self.separatorView => \.backgroundColor => Theme.current.color.selection.transform { $0?.with( hue: siteColor.hue ) }
                self.backgroundImage?.mode = .custom( color: { [unowned self] in
                    Theme.current.color.panel.get(forTraits: self.traitCollection)?.with( hue: siteColor.hue )
                } )
                self.backgroundImage?.imageColor = siteColor
            }
            else {
                self.separatorView => \.backgroundColor => Theme.current.color.selection
                self.backgroundImage?.mode = .custom( color: { [unowned self] in
                    Theme.current.color.panel.get(forTraits: self.traitCollection)
                } )
                self.backgroundImage?.imageColor = nil
            }

            if let backgroundImage = self.backgroundImage {
                if self.isSelected {
                    backgroundImage.alpha = .on
                    backgroundImage.image = self.site?.preview.image
                }
                else {
                    UIView.animate( withDuration: 0, animations: {
                        backgroundImage.alpha = .off
                    }, completion: { _ in
                        if !self.isSelected {
                            backgroundImage.image = nil
                        }
                    } )
                }
            }

            let isNew = self.result?.isNew ?? false
            if let resultCaption = self.result.flatMap( { NSMutableAttributedString( attributedString: $0.subtitle ) } ) {
                if isNew {
                    resultCaption.append( NSAttributedString( string: " (new site)" ) )
                }
                self.nameLabel.attributedText = resultCaption
            }
            else {
                self.nameLabel.attributedText = nil
            }

            self.maskButton.image = .icon( self.unmasked ? "eye" : "eye-slash", invert: true )
            if case .identification = self.purpose, InAppFeature.logins.isEnabled {
                self.purposeButton.image = .icon( "id-card-clip" )
            }
            else if case .recovery = self.purpose, InAppFeature.answers.isEnabled {
                self.purposeButton.image = .icon( "comments-question-check" )
            }
            else {
                self.purpose = .authentication
                self.purposeButton.image = .icon( "key" )
            }

            self.maskButton.isSelected = self.unmasked
            self.maskButton.isUserInteractionEnabled = (self.site?.user?.maskPasswords ?? false)
            self.maskButton.alpha = self.maskButton.isUserInteractionEnabled ? .on : .off
            self.purposeButton.alpha = self.purposeButton.isUserInteractionEnabled ? .on : .off
            self.modeStack.isUserInteractionEnabled = self.isSelected
            self.modeStack.alpha = self.modeStack.isUserInteractionEnabled ? .on : .off
            self.actionStack.isUserInteractionEnabled = self.isSelected && !isNew
            self.actionStack.alpha = self.actionStack.isUserInteractionEnabled ? .on : .off
            self.newButton.isUserInteractionEnabled = self.isSelected && isNew
            self.newButton.alpha = self.newButton.isUserInteractionEnabled ? .on : .off
            self.selectionConfiguration.isActive = self.isSelected
            self.primaryGestureRecognizer?.isEnabled = self.isSelected

            self.resultLabel.isSecureTextEntry =
            (self.site?.user?.maskPasswords ?? true) && !self.unmasked && self.purpose == .authentication
            self.resultLabel.isUserInteractionEnabled = !self.resultLabel.isSecureTextEntry
            self.resultLabel.alpha = self.resultLabel.isUserInteractionEnabled ? .on : .off

            self.nameLabel => \.font => (self.resultLabel.isSecureTextEntry ? Theme.current.font.title3 : Theme.current.font.callout)

            self.site?.result( keyPurpose: self.purpose )?.token.then( on: .main ) { [weak self] in
                do {
                    self?.resultLabel.text = try $0.get()
                }
                catch {
                    mperror( title: "Couldn't update site cell", error: error )
                }
            }
        }
    }

    struct SiteAction {
        let tracking:   Tracking?
        let title:      String
        let icon:       NSAttributedString?
        let appearance: [Appearance]
        let action:     (Site, SpectreKeyPurpose?, Appearance) -> Void

        enum Appearance: Hashable {
            case cell, menu, mode, primary, feature(_: InAppFeature)
        }
    }
}

protocol CellAppearance {
    func willDisplay()
    func didEndDisplaying()
}
