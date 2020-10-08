//
// Created by Maarten Billemont on 2018-03-25.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit
import AVKit

class MPServicesTableView: UITableView, UITableViewDelegate, UITableViewDataSource, Observable, MPUserObserver, Updatable {
    public let observers = Observers<MPServicesViewObserver>()
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
            let selectedPath = self.resultSource.indexPath( where: { $0?.value == self.selectedService } )
            if self.indexPathForSelectedRow != selectedPath {
                self.selectRow( at: selectedPath, animated: UIView.areAnimationsEnabled, scrollPosition: .middle )
            }
            else if let selectedPath = selectedPath {
                self.scrollToRow( at: selectedPath, at: .middle, animated: UIView.areAnimationsEnabled )
            }

            if oldValue != self.selectedService {
                self.observers.notify { $0.serviceWasSelected( service: self.selectedService ) }
            }
        }
    }
    public var query: String? {
        didSet {
            if oldValue != self.query {
                self.updateTask.request()
            }
        }
    }

    private lazy var resultSource = DataSource<MPQuery.Result<MPService>>( tableView: self )
    private var newServiceResult: MPQuery.Result<MPService>?
    private lazy var updateTask = DispatchTask( queue: .global(), deadline: .now() + .milliseconds( 100 ), update: self )

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

        self.register( ServiceCell.self )
        self.register( LiefsteCell.self )
        self.delegate = self
        self.dataSource = self
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
        var resultSource = [ [ MPQuery.Result<MPService>? ] ]()
        if let user = self.user, user.masterKeyFactory != nil {

            // Determine search state and filter user services
            selectedResult = self.resultSource.elements().first( where: { $1?.value === self.selectedService } )?.element
            let selectionFollowsQuery = self.newServiceResult === selectedResult || selectedResult?.exact ?? false
            let results = MPQuery( self.query ).find( user.services.sorted() ) { $0.serviceName }
            let exactResult = results.first { $0.exact }
            resultSource.append( results )

            // Add "new service" result if there is a query and no exact result
            if let query = self.query,
               !query.isEmpty, exactResult == nil {
                self.newServiceResult?.value.serviceName = query

                if self.newServiceResult == nil || LiefsteCell.is( result: self.newServiceResult ) {
                    self.newServiceResult = MPQuery.Result<MPService>( value: MPService( user: user, serviceName: query ), keySupplier: { $0.serviceName } )
                }

                self.newServiceResult?.matches( query: query )
                resultSource.append( [ self.newServiceResult ] )
            }
            else {
                self.newServiceResult = nil
            }

            // Special case for selected service: keep selection on the service result that matches the query
            if selectionFollowsQuery {
                selectedResult = exactResult ?? self.newServiceResult
            }
            if self.newServiceResult != selectedResult,
               let selectedResult_ = selectedResult,
               !results.contains( selectedResult_ ) {
                selectedResult = nil
            }
        }

        DispatchQueue.main.perform {
            // Update the services table to show the newly filtered services
            self.resultSource.update( resultSource ) { _ in
                self.selectedService = selectedResult?.value
            }

            // Light-weight reload the cell content without fully reloading the cell rows.
            self.resultSource.elements().forEach { path, element in
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

    // MARK: --- UITableViewDataSource ---

    @available(iOS 13, *)
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        (self.resultSource.element( at: indexPath )?.value).flatMap { service in
            UIContextMenuConfiguration(
                    indexPath: indexPath, previewProvider: { _ in MPServicePreviewController( service: service ) }, actionProvider: { _, configuration in
                UIMenu( title: service.serviceName, children: [
                    UIAction( title: "Delete", image: .icon( "" ), identifier: UIAction.Identifier( "delete" ), attributes: .destructive ) { action in
                        configuration.action = action
                        service.user.services.removeAll { $0 === service }
                    },
                    UIAction( title: "Details", image: .icon( "" ), identifier: UIAction.Identifier( "settings" ) ) { action in
                        configuration.action = action
                        self.observers.notify { $0.serviceDetailsAction( service: service ) }
                    },
                    UIAction( title: "Copy Login Name 🅿︎", image: .icon( "" ), identifier: UIAction.Identifier( "login" ), attributes: InAppFeature.premium.enabled() ? []: .disabled ) { action in
                        configuration.action = action
                        let event = MPTracker.shared.begin( named: "service #copy" )
                        service.copy( keyPurpose: .identification, by: self ).then {
                            do {
                                let result = try $0.get()
                                event.end(
                                        [ "result": $0.name,
                                          "from": "cell>menu>login",
                                          "counter": "\(result.counter)",
                                          "purpose": "\(result.purpose)",
                                          "type": "\(result.type)",
                                          "algorithm": "\(result.algorithm)",
                                          "entropy": MPAttacker.entropy( type: result.3 ) ?? MPAttacker.entropy( string: result.token ) ?? 0,
                                        ] )
                            }
                            catch {
                                event.end( [ "result": $0.name ] )
                            }
                        }
                    },
                    UIAction( title: "Copy Password", image: .icon( "" ), identifier: UIAction.Identifier( "password" ) ) { action in
                        configuration.action = action
                        let event = MPTracker.shared.begin( named: "service #copyPassword" )
                        service.copy( keyPurpose: .authentication, by: self ).then {
                            do {
                                let result = try $0.get()
                                event.end(
                                        [ "result": $0.name,
                                          "from": "cell>menu>password",
                                          "counter": "\(result.counter)",
                                          "purpose": "\(result.purpose)",
                                          "type": "\(result.type)",
                                          "algorithm": "\(result.algorithm)",
                                          "entropy": MPAttacker.entropy( type: result.3 ) ?? MPAttacker.entropy( string: result.token ) ?? 0,
                                        ] )
                            }
                            catch {
                                event.end( [ "result": $0.name ] )
                            }
                        }
                    },
                ] )
            } )
        }
    }

    @available(iOS 13, *)
    func tableView(_ tableView: UITableView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let indexPath = configuration.indexPath, let view = self.cellForRow( at: indexPath )
        else { return nil }

        configuration.event = MPTracker.shared.begin( named: "service #menu" )

        let parameters = UIPreviewParameters()
        parameters.backgroundColor = self.resultSource.element( at: indexPath )?.value.color?.with( alpha: .long )
        return UITargetedPreview( view: view, parameters: parameters )
    }

    @available(iOS 13, *)
    func tableView(_ tableView: UITableView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let indexPath = configuration.indexPath, let view = self.cellForRow( at: indexPath )
        else { return nil }

        configuration.event?.end( [ "action": configuration.action?.identifier.rawValue ?? "none" ] )

        let parameters = UIPreviewParameters()
        parameters.backgroundColor = self.resultSource.element( at: indexPath )?.value.color?.with( alpha: .long )
        return UITargetedPreview( view: view, parameters: parameters )
    }

    @available(iOS 13, *)
    func tableView(_ tableView: UITableView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        self.selectedService = self.resultSource.element( at: configuration.indexPath )?.value
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if let service = self.resultSource.element( at: indexPath )?.value, editingStyle == .delete {
            MPTracker.shared.event( named: "service #delete" )

            service.user.services.removeAll { $0 === service }
        }
    }

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

        let cell = ServiceCell.dequeue( from: tableView, indexPath: indexPath )
        cell.servicesView = self
        cell.result = result
        cell.new = cell.result == self.newServiceResult
        cell.update()
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

    func userDidUpdateServices(_ user: MPUser) {
        self.updateTask.request()
    }

    // MARK: --- Types ---

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
        public var new = false {
            didSet {
                if oldValue != self.new {
                    self.updateTask.request()
                }
            }
        }

        private var mode            = MPKeyPurpose.authentication {
            didSet {
                if oldValue != self.mode {
                    self.updateTask.request()
                }
            }
        }
        private let backgroundImage = MPBackgroundView( mode: .custom )
        private let modeButton      = MPButton( identifier: "services.service #mode", image: .icon( "" ), background: false )
        private let settingsButton  = MPButton( identifier: "services.service #service_settings", image: .icon( "" ), background: false )
        private let newButton       = MPButton( identifier: "services.service #add", image: .icon( "" ), background: false )
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
            self.contentView.addGestureRecognizer( UITapGestureRecognizer( target: self, action: #selector( cellAction ) ) )

            self.contentStack.axis = .vertical

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

            self.settingsButton.button.addTarget( self, action: #selector( settingsAction ), for: .primaryActionTriggered )

            self.newButton.tapEffect = false
            self.newButton.isUserInteractionEnabled = false

            self.modeButton.tapEffect = false
            self.modeButton.button.addTarget( self, action: #selector( modeAction ), for: .primaryActionTriggered )

            // - Hierarchy
            self.contentView.addSubview( self.contentStack )
            self.contentView.addSubview( self.modeButton )
            self.contentView.addSubview( self.settingsButton )
            self.contentView.addSubview( self.newButton )

            // - Layout
            LayoutConfiguration( view: self.modeButton )
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                    .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                    .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                    .activate()

            LayoutConfiguration( view: self.settingsButton )
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
                    .constrainTo { $1.trailingAnchor.constraint( lessThanOrEqualTo: self.settingsButton.leadingAnchor ) }
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
                                   .with( priority: .defaultHigh + 1 )
                }
            }.needs( .update() )
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

        @objc
        func settingsAction() {
            if let service = self.service {
                self.servicesView?.observers.notify { $0.serviceDetailsAction( service: service ) }
            }
        }

        @objc
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
            self.servicesView?.selectedService = self.service
            if let service = self.service, self.new {
                service.user.services.append( service )
            }

            let event = MPTracker.shared.begin( named: "service #copy" )
            self.service?.copy( keyPurpose: self.mode, by: self ).then {
                do {
                    let result = try $0.get()
                    event.end(
                            [ "result": $0.name,
                              "from": "cell",
                              "counter": "\(result.counter)",
                              "purpose": "\(result.purpose)",
                              "type": "\(result.type)",
                              "algorithm": "\(result.algorithm)",
                              "entropy": MPAttacker.entropy( type: result.3 ) ?? MPAttacker.entropy( string: result.token ) ?? 0,
                            ] )
                }
                catch {
                    event.end( [ "result": $0.name ] )
                }
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

            guard let service = self.service
            else { return }

            DispatchQueue.main.promise {
                self.backgroundImage.image = self.service?.image
                self.backgroundImage => \.backgroundColor => Theme.current.color.selection
                        .transform { [unowned self] in $0?.with( hue: self.service?.color?.hue ) }

                if let resultCaption = self.result.flatMap( { NSMutableAttributedString( attributedString: $0.attributedKey ) } ) {
                    if self.new {
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
                self.settingsButton.alpha = self.isSelected && !self.new ? .on: .off
                self.newButton.alpha = self.isSelected && self.new ? .on: .off
                self.selectionConfiguration.activated = self.isSelected
                self.resultLabel.isSecureTextEntry = self.mode == .authentication && self.service?.user.maskPasswords ?? true
            }.promising {
                service.result( keyPurpose: self.mode )
            }.then( on: DispatchQueue.main ) {
                do {
                    self.resultLabel.text = try $0.get().token
                }
                catch {
                    mperror( title: "Couldn't calculate service \(self.mode)", error: error )
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
            self.contentView.layoutMargins = UIEdgeInsets( top: 80, left: 80, bottom: 80, right: 80 )

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
}

protocol MPServicesViewObserver {
    func serviceWasSelected(service selectedSite: MPService?)
    func serviceDetailsAction(service: MPService)
}
