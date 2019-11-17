//
//  MPAppDelegate.swift
//  MasterPassword
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit
import CoreServices
import Sentry

@UIApplicationMain
class MPAppDelegate: UIResponder, UIApplicationDelegate, MPConfigObserver {

    lazy var window: UIWindow? = UIWindow()

    // MARK: --- Life ---

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        MPLogSink.shared.register()

        // Sentry
        do {
            Client.shared = try Client( dsn: "" )
            Client.shared?.enabled = appConfig.sendInfo as NSNumber
            try Client.shared?.startCrashHandler()
            Client.shared?.enableAutomaticBreadcrumbTracking()

            mpw_log_sink_register( { event in
                if let event: MPLogEvent = event?.pointee, event.level <= .info,
                   let message = String( safeUTF8: event.message ) {
                    var severity = SentrySeverity.debug
                    switch event.level {
                        case .info:
                            severity = .info
                        case .warning:
                            severity = .warning
                        case .error:
                            severity = .error
                        case .fatal:
                            severity = .fatal
                        default: ()
                    }

                    if event.level <= .error {
                        let sentryEvent = Event( level: severity )
                        sentryEvent.message = message
                        sentryEvent.logger = "mpw"
                        sentryEvent.timestamp = Date( timeIntervalSince1970: TimeInterval( event.occurrence ) )
                        var file = String( safeUTF8: event.file ) ?? "-"
                        file = file.lastIndex( of: "/" ).flatMap( { String( file.suffix( from: file.index( after: $0 ) ) ) } ) ?? file
                        sentryEvent.tags = [ "file": file, "line": "\(event.line)", "function": String( safeUTF8: event.function ) ?? "-" ]
                        Client.shared?.appendStacktrace( to: sentryEvent )
                        Client.shared?.send( event: sentryEvent )
                    }
                    else {
                        let breadcrumb = Breadcrumb( level: severity, category: "mpw" )
                        breadcrumb.type = message
                        breadcrumb.message = message
                        breadcrumb.timestamp = Date( timeIntervalSince1970: TimeInterval( event.occurrence ) )
                        var file = String( safeUTF8: event.file ) ?? "-"
                        file = file.lastIndex( of: "/" ).flatMap( { String( file.suffix( from: file.index( after: $0 ) ) ) } ) ?? file
                        breadcrumb.data = [ "file": file, "line": "\(event.line)", "function": String( safeUTF8: event.function ) ?? "-" ]
                        Client.shared?.breadcrumbs.add( breadcrumb )
                    }
                }
            } )
        }
        catch {
            err( "Couldn't install Sentry [>TRC]" )
            trc( "[>] %@", error )
        }

        // Start
        MPTracker.shared.startup()
        self.window?.tintColor = appConfig.theme.color.tint.get()
        self.window?.rootViewController = MPNavigationController( rootViewController: MPUsersViewController() )
        self.window?.makeKeyAndVisible()

        appConfig.observers.register( observer: self )

        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        dbg( "opening: %@, options: %@", url, options )
        if let utisValue = UTTypeCreateAllIdentifiersForTag(
                kUTTagClassFilenameExtension, url.pathExtension as CFString, nil )?.takeRetainedValue(),
           let utis = utisValue as? Array<String> {
            for format in MPMarshalFormat.allCases {
                if let uti = format.uti, utis.contains( uti ) {
                    dbg( "connecting to: %@", url )
                    MPURLUtils.session.dataTask( with: url, completionHandler: { (data, response, error) in
                        dbg( "connected to: %@, response: %@, error: %@", url, response, error )
                        if let data = data, error == nil {
                            MPMarshal.shared.import( data: data )
                        }
                        else {
                            mperror( title: "Couldn't open document", details: url.lastPathComponent, error: error )
                        }
                    } ).resume()
                    return true
                }
            }
        }

        return false
    }

    // MARK: --- MPConfigObserver ---

    func didChangeConfig() {
        // Sentry
        Client.shared?.enabled = appConfig.sendInfo as NSNumber

        DispatchQueue.main.perform {
            self.window?.tintColor = appConfig.theme.color.tint.get()
        }
    }
}
