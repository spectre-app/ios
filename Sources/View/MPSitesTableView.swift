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
    private var isSelecting = false

    // MARK: - Life

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

    // MARK: - Internal

    func dataSection(section: Int) -> NSArray {
        return self.data.object( at: section ) as! NSArray
    }

    func dataRow(section: Int, row: Int) -> MPQuery.Result<MPSite> {
        return self.dataSection( section: section ).object( at: row ) as! MPQuery.Result<MPSite>
    }

    func updateSites() {
        let newSites: NSMutableArray = []
        let results = MPQuery( self.query ).find( self.user?.sites.sorted() ?? [] ) { $0.siteName }
        newSites.add( results )

        if let user = self.user,
           let query = self.query,
           (results.first { $0.exact }) == nil {
            if let newSiteResult = self.newSiteResult {
                newSiteResult.value.siteName = query
                newSiteResult.matches(query: query)
            } else {
                self.newSiteResult = MPQuery.Result<MPSite>( value: MPSite( user: user, named: query ), keySupplier: { $0.siteName } )
            }
            newSites.add( [ self.newSiteResult ] )
        }

        PearlMainQueue {
            self.updateDataSource( self.data, toSections: newSites, reloadItems: self.data, with: .automatic )
        }
    }

    // MARK: - UITableViewDelegate

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.selectRow( at: nil, animated: true, scrollPosition: .none )
        self.selectedSite = nil
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        self.isSelecting = true;
        return indexPath
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if !isSelecting {
            self.selectedSite = nil
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.selectedSite = self.dataRow( section: indexPath.section, row: indexPath.row ).value
        self.isSelecting = false
    }

    // MARK: - UITableViewDataSource

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

        return cell
    }

    // MARK: - MPUserObserver

    func userDidLogin() {
        self.updateSites()
    }

    func userDidLogout() {
        self.updateSites()
    }

    func userDidChange() {
    }

    func userDidUpdateSites() {
        self.updateSites()
    }

    // MARK: - Types

    class SiteCell: UITableViewCell, MPSiteObserver {
        var result: MPQuery.Result<MPSite>? {
            didSet {
                self.site = self.result?.value
            }
        }
        var site:   MPSite? {
            willSet {
                self.site?.observers.unregister( self )
            }
            didSet {
                if let site = self.site {
                    site.observers.register( self ).siteDidChange()
                }
            }
        }

        let indicatorView = UIView()
        let passwordLabel = UILabel()
        let nameLabel     = UILabel()
        let copyButton    = MPButton( image: nil, title: "copy" )

        // MARK: - Life

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
            self.passwordLabel.font = UIFont( name: "SourceCodePro-Black", size: 28 )
            self.passwordLabel.textAlignment = .natural
            self.passwordLabel.textColor = UIColor( red: 0.4, green: 0.8, blue: 1, alpha: 1 )
            self.passwordLabel.shadowColor = .black

            self.nameLabel.font = UIFont.preferredFont( forTextStyle: .caption1 )
            self.nameLabel.textAlignment = .natural
            self.nameLabel.textColor = UIColor.lightText
            self.nameLabel.shadowColor = .black

            self.copyButton.darkBackground = true
            self.copyButton.button.addTarget( self, action: #selector( copySite ), for: .touchUpInside )

            // - Hierarchy
            self.contentView.addSubview( self.passwordLabel )
            self.contentView.addSubview( self.nameLabel )
            self.contentView.addSubview( self.copyButton )

            // - Layout
            ViewConfiguration( view: self.passwordLabel )
                    .constrainTo { $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.topAnchor ) }
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                    .huggingPriorityHorizontal( .fittingSizeLevel, vertical: .fittingSizeLevel )
                    .activate()

            ViewConfiguration( view: self.nameLabel )
                    .constrainTo { $1.topAnchor.constraint( equalTo: self.passwordLabel.bottomAnchor ) }
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: self.passwordLabel.leadingAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( lessThanOrEqualTo: self.passwordLabel.trailingAnchor ) }
                    .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.layoutMarginsGuide.bottomAnchor ) }
                    .activate()

            ViewConfiguration( view: self.copyButton )
                    .constrainTo { $1.centerYAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerYAnchor ) }
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: self.passwordLabel.trailingAnchor, constant: 20 ) }
                    .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                    .activate()
        }

        @objc
        func copySite() {
            PearlNotMainQueue {
                if let site = self.site,
                   let password = site.result() {

                    if #available( iOS 10.0, * ) {
                        UIPasteboard.general.setItems(
                                [ [ UIPasteboardTypeAutomatic: password ] ],
                                options: [
                                    UIPasteboard.OptionsKey.localOnly: true,
                                    UIPasteboard.OptionsKey.expirationDate: Date( timeIntervalSinceNow: 3 * 60 )
                                ] )

                        PearlMainQueue {
                            MPAlertView( title: site.siteName, message: "Password Copied (3 min)" ).show( in: self )
                        }
                    }
                    else {
                        UIPasteboard.general.string = password;

                        PearlMainQueue {
                            MPAlertView( title: site.siteName, message: "Password Copied" ).show( in: self )
                        }
                    }
                }
            }
        }

        // MARK: - MPSiteObserver

        func siteDidChange() {
            PearlMainQueue {
                self.nameLabel.attributedText = self.result?.attributedKey
                self.indicatorView.backgroundColor = self.site?.color?.withAlphaComponent( 0.85 )
            }
            PearlNotMainQueue {
                let password = self.site?.result()

                PearlMainQueue {
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
