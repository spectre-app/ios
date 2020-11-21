//
// Created by Maarten Billemont on 2018-03-25.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit
import AVKit

class MPServicesTableView: UITableView, UITableViewDelegate, MPUserObserver, Updatable {
    public var user: MPUser? {
        willSet {
            self.user?.observers.unregister( observer: self )
            self.query = nil
        }
        didSet {
            self.user?.observers.register( observer: self )
            self.update()
        }
    }
    public var selectedService: MPService? {
        didSet {
            let selectedPath = self.servicesDataSource.indexPath( where: { $0?.value == self.selectedService } )
            if self.indexPathForSelectedRow != selectedPath {
                self.selectRow( at: selectedPath, animated: UIView.areAnimationsEnabled, scrollPosition: .middle )
            }
            else if let selectedPath = selectedPath, !(self.indexPathsForVisibleRows?.contains( selectedPath ) ?? false) {
                self.scrollToRow( at: selectedPath, at: .middle, animated: UIView.areAnimationsEnabled )
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
    public var serviceActions = [ ServiceAction ]() {
        didSet {
            self.updateTask.request()
        }
    }
    public var preferredFilter: ((MPService) -> Bool)? {
        didSet {
            self.updateTask.request()
        }
    }

    private lazy var servicesDataSource = ServicesSource( view: self )
    private lazy var updateTask         = DispatchTask( queue: .global(), deadline: .now() + .milliseconds( 100 ), update: self )

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

        self.delegate = self
        self.dataSource = self.servicesDataSource
        self.backgroundColor = .clear
        self.isOpaque = false
        self.separatorStyle = .singleLine
        self => \.separatorColor => Theme.current.color.mute
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    // MARK: --- Internal ---

    func update() {
        self.updateTask.cancel()

        var selectedResult: MPQuery.Result<MPService>?
        var elementsBySection = [ [ MPQuery.Result<MPService>? ] ]()

        if let user = self.user, user.masterKeyFactory != nil {
            selectedResult = self.servicesDataSource.firstElement( where: { $0?.value === self.selectedService } )
            var newServiceResult = self.servicesDataSource.firstElement( where: { $0?.value.isNew ?? false } )
            let selectionFollowsQuery = selectedResult.flatMap { $0.value.isNew || $0.isExact } ?? false

            // Filter services by query.
            let results = MPQuery( self.query ).filter( user.services.sorted(), key: { $0.serviceName } )
            let exactResult = results.first( where: { $0.isExact } )

            // Divide the results into sections.
            if let preferredFilter = self.preferredFilter {
                var preferred = [ MPQuery.Result<MPService>? ](),
                    remaining = [ MPQuery.Result<MPService>? ]()
                for result in results {
                    if preferredFilter( result.value ) {
                        result.flags.insert( Flag.preferred.rawValue )
                        preferred.append( result )
                    }
                    else {
                        result.flags.remove( Flag.preferred.rawValue )
                        remaining.append( result )
                    }
                }
                elementsBySection.append( preferred )
                elementsBySection.append( remaining )
            }
            else {
                elementsBySection.append( results )
            }

            // Add "new service" result if there is a query and no exact result
            if let query = self.query, !query.isEmpty, exactResult == nil {
                if let newServiceResult = newServiceResult, !LiefsteCell.is( result: newServiceResult ) {
                    newServiceResult.value.serviceName = query
                }
                else {
                    newServiceResult = MPQuery.Result<MPService>( value: MPService( user: user, serviceName: query ), keySupplier: { $0.serviceName } )
                }

                newServiceResult?.matches( query: query )
                elementsBySection.append( [ newServiceResult ] )
            }
            else {
                newServiceResult = nil
            }

            // Special case for selected service: keep selection on the service result that matches the query
            if selectionFollowsQuery {
                selectedResult = exactResult ?? newServiceResult
            }
            if newServiceResult != selectedResult, let selectedResult_ = selectedResult, !results.contains( selectedResult_ ) {
                selectedResult = nil
            }
        }

        DispatchQueue.main.perform {
            // Update the services table to show the newly filtered services
            self.servicesDataSource.update( elementsBySection ) { _ in
                self.selectedService = selectedResult?.value
            }

            // Light-weight reload the cell content without fully reloading the cell rows.
            self.servicesDataSource.elements().forEach { path, element in
                (self.cellForRow( at: path ) as? ServiceCell)?.result = element
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

    @available(iOS 13, *)
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        (self.servicesDataSource.element( at: indexPath )?.value).flatMap { service in
            UIContextMenuConfiguration(
                    indexPath: indexPath, previewProvider: { _ in MPServicePreviewController( service: service ) }, actionProvider: { _, configuration in
                UIMenu( title: service.serviceName, children: [
                    UIAction( title: "Delete", image: .icon( "" ), identifier: UIAction.Identifier( "delete" ), attributes: .destructive ) { action in
                        configuration.action = action
                        service.user.services.removeAll { $0 === service }
                    }
                ] + self.serviceActions.filter( { $0.appearance.contains( .menu ) } ).map { serviceAction in
                    UIAction( title: serviceAction.title, image: .icon( serviceAction.icon ), identifier: UIAction.Identifier( serviceAction.identifier ) ) { action in
                        configuration.action = action
                        serviceAction.action( service, nil, .menu )
                    }
                } )
            } )
        }
    }

    @available(iOS 13, *)
    func tableView(_ tableView: UITableView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let indexPath = configuration.indexPath, let view = self.cellForRow( at: indexPath )
        else { return nil }

        configuration.event = MPTracker.shared.begin( named: "service #menu" )

        let parameters = UIPreviewParameters()
        parameters.backgroundColor = self.servicesDataSource.element( at: indexPath )?.value.color?.with( alpha: .long )
        return UITargetedPreview( view: view, parameters: parameters )
    }

    @available(iOS 13, *)
    func tableView(_ tableView: UITableView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let indexPath = configuration.indexPath, let view = self.cellForRow( at: indexPath )
        else { return nil }

        configuration.event?.end( [ "action": configuration.action?.identifier.rawValue ?? "none" ] )

        let parameters = UIPreviewParameters()
        parameters.backgroundColor = self.servicesDataSource.element( at: indexPath )?.value.color?.with( alpha: .long )
        return UITargetedPreview( view: view, parameters: parameters )
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.selectedService = self.servicesDataSource.element( at: self.indexPathForSelectedRow )?.value
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        self.selectedService = self.servicesDataSource.element( at: self.indexPathForSelectedRow )?.value
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

    func userDidUpdateServices(_ user: MPUser) {
        self.updateTask.request()
    }

    // MARK: --- Types ---

    enum Flag: Int {
        case preferred
    }

    class ServicesSource: DataSource<MPQuery.Result<MPService>> {
        let view: MPServicesTableView

        init(view: MPServicesTableView) {
            self.view = view
            view.register( ServiceCell.self )
            view.register( LiefsteCell.self )

            super.init( tableView: view )
        }

        override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
            !(self.element( at: indexPath )?.value.isNew ?? true)
        }

        override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
            if let service = self.element( at: indexPath )?.value, editingStyle == .delete {
                MPTracker.shared.event( named: "service #delete" )

                service.user.services.removeAll { $0 === service }
            }
        }

        override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let result = self.element( at: indexPath )
            if LiefsteCell.is( result: result ) {
                return LiefsteCell.dequeue( from: tableView, indexPath: indexPath )
            }

            let cell = ServiceCell.dequeue( from: tableView, indexPath: indexPath )
            cell.servicesView = self.view
            cell.result = result
            cell.update()
            return cell
        }
    }

    class ServiceCell: UITableViewCell, Updatable, MPServiceObserver, MPUserObserver, MPConfigObserver, InAppFeatureObserver {
        public weak var servicesView: MPServicesTableView?
        public weak var result:       MPQuery.Result<MPService>? {
            willSet {
                self.service?.observers.unregister( observer: self )
                self.service?.user.observers.unregister( observer: self )
            }
            didSet {
                if let service = self.service {
                    service.observers.register( observer: self )
                    service.user.observers.register( observer: self )
                }

                self.updateTask.request()
            }
        }
        public var service: MPService? {
            self.result?.value
        }

        private var mode            = MPKeyPurpose.authentication {
            didSet {
                if oldValue != self.mode {
                    self.updateTask.request()
                }
            }
        }
        private let backgroundImage = MPBackgroundView( mode: .clear )
        private let modeButton      = MPButton( identifier: "services.service #mode", image: .icon( "" ), background: false )
        private let newButton       = MPButton( identifier: "services.service #add", image: .icon( "" ), background: false )
        private let actionsStack    = UIStackView()
        private let selectionView   = UIView()
        private let resultLabel     = UITextField()
        private let captionLabel    = UILabel()
        private lazy var contentStack = UIStackView( arrangedSubviews: [ self.selectionView, self.resultLabel, self.captionLabel ] )
        private lazy var updateTask   = DispatchTask( named: self.service?.serviceName, queue: .main, update: self )

        private var selectionConfiguration: LayoutConfiguration<UIStackView>!

        // MARK: --- Life ---

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init( style: style, reuseIdentifier: reuseIdentifier )

            appConfig.observers.register( observer: self )
            InAppFeature.observers.register( observer: self )

            // - View
            self.isOpaque = false
            self.clipsToBounds = true
            self.backgroundColor = .clear

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
                if let service = self.service, service.isNew {
                    service.user.services.append( service )
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
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                    .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                    .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                    .activate()

            LayoutConfiguration( view: self.actionsStack )
                    .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                    .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                    .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                    .activate()

            LayoutConfiguration( view: self.newButton )
                    .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                    .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                    .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                    .activate()

            LayoutConfiguration( view: self.contentStack )
                    .constrainTo { $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.topAnchor ) }
                    .constrainTo { $1.leadingAnchor.constraint( greaterThanOrEqualTo: self.modeButton.trailingAnchor ) }
                    .constrainTo { $1.centerXAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerXAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( lessThanOrEqualTo: self.actionsStack.leadingAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( lessThanOrEqualTo: self.newButton.leadingAnchor ) }
                    .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.layoutMarginsGuide.bottomAnchor ) }
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

            self.selectionConfiguration = LayoutConfiguration( view: self.contentStack ) { active, inactive in
                active.constrainTo {
                    $1.heightAnchor.constraint( equalTo: $0.widthAnchor, multiplier: .short )
                                   .with( priority: .defaultHigh + 10 )
                }
            }.needs( .update() )
        }

        override func didMoveToSuperview() {
            super.didMoveToSuperview()

            self.actionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            self.servicesView?.serviceActions.filter( { $0.appearance.contains( .cell ) } ).forEach { serviceAction in
                self.actionsStack.addArrangedSubview( MPButton( identifier: serviceAction.identifier, image: .icon( serviceAction.icon ), background: false ) { [unowned self] _, _ in
                    if let service = self.service {
                        serviceAction.action( service, self.mode, .cell )
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

        // MARK: --- MPUserObserver ---

        func userDidChange(_ user: MPUser) {
            self.updateTask.request()
        }

        // MARK: --- MPServiceObserver ---

        func serviceDidChange(_ service: MPService) {
            self.updateTask.request()
        }

        // MARK: --- MPConfigObserver ---

        func didChangeConfig() {
            self.updateTask.request()
        }

        // MARK: --- InAppFeatureObserver ---

        func featureDidChange(_ feature: InAppFeature) {
            self.updateTask.request()
        }

        // MARK: --- Private ---

        public func update() {
            self.updateTask.cancel()

            DispatchQueue.main.perform {
                self.backgroundImage.color = self.service?.color
                self.backgroundImage.image = self.service?.image
                self.backgroundImage => \.backgroundColor => Theme.current.color.selection
                        .transform { [weak self] in $0?.with( hue: self?.service?.color?.hue ) }
                self => \.backgroundColor => Theme.current.color.shadow
                        .transform { [weak self] in self?.result?.flags.contains( Flag.preferred.rawValue ) ?? false ? $0: .clear }

                let isNew = self.service?.isNew ?? false
                if let resultCaption = self.result.flatMap( { NSMutableAttributedString( attributedString: $0.attributedKey ) } ) {
                    if isNew {
                        resultCaption.append( NSAttributedString( string: " (new service)" ) )
                    }
                    self.captionLabel.attributedText = resultCaption
                }
                else {
                    self.captionLabel.attributedText = nil
                }

                if !InAppFeature.premium.enabled() {
                    self.mode = .authentication
                }
                switch self.mode {
                    case .authentication:
                        self.modeButton.image = .icon( "" )
                    case .identification:
                        self.modeButton.image = .icon( "" )
                    case .recovery:
                        self.modeButton.image = .icon( "" )
                    @unknown default:
                        self.modeButton.image = nil
                }

                self.modeButton.alpha = InAppFeature.premium.enabled() ? .on: .off
                self.modeButton.isUserInteractionEnabled = self.modeButton.alpha != .off
                self.actionsStack.alpha = self.isSelected && !isNew ? .on: .off
                self.actionsStack.isUserInteractionEnabled = self.actionsStack.alpha != .off
                self.newButton.alpha = self.isSelected && isNew ? .on: .off
                self.newButton.isUserInteractionEnabled = self.newButton.alpha != .off
                self.selectionConfiguration.isActive = self.isSelected
                self.resultLabel.isSecureTextEntry = self.mode == .authentication && self.service?.user.maskPasswords ?? true

                self.service?.result( keyPurpose: self.mode ).token.then( on: .main ) {
                    do {
                        self.resultLabel.text = try $0.get()
                    }
                    catch {
                        mperror( title: "Couldn't update service cell.", error: error )
                    }
                }
            }
        }
    }

    class LiefsteCell: UITableViewCell {
        private let emitterView = MPEmitterView()
        private let propLabel   = UILabel()
        private var player: AVPlayer?

        class func `is`(result: MPQuery.Result<MPService>?) -> Bool {
            result?.value.serviceName == "liefste"
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
                    .constrain()
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
            MPTracker.shared.event( named: "liefste" )

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

    struct ServiceAction {
        let identifier: String
        let title:      String
        let icon:       String
        let appearance: [Appearance]
        let action:     (MPService, MPKeyPurpose?, Appearance) -> Void

        enum Appearance {
            case cell, menu
        }
    }
}
