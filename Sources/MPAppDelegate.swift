//
//  MPAppDelegate.swift
//  MasterPassword
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit
import CoreServices
import Firebase

@UIApplicationMain
class MPAppDelegate: UIResponder, UIApplicationDelegate, CrashlyticsDelegate {

    let window = UIWindow()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        //PearlLogger.get().minimumLevel = .trace
        //PearlLogger.get().printLevel = .trace
        Crashlytics.sharedInstance().delegate = self
        FirebaseApp.configure()
        PearlLogger.get().registerListener {
            CLSLogv( "%@", getVaList( [ $0.messageDescription() ] ) )
            return true
        }
        inf( "Launching \(productName) \(PearlInfoPlist.get().cfBundleShortVersionString ?? "?") (\(PearlInfoPlist.get().cfBundleVersion ?? "?"))" )

        // Start UI
        self.window.tintColor = MPTheme.global.color.brand.get()
        self.window.rootViewController = MPNavigationController( rootViewController: MPUsersViewController() )
        self.window.makeKeyAndVisible()

        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        if let utisValue = UTTypeCreateAllIdentifiersForTag(
                kUTTagClassFilenameExtension, url.pathExtension as CFString, nil )?.takeRetainedValue(),
           let utis = utisValue as? Array<String> {
            for format in MPMarshalFormat.allCases {
                if let uti = format.uti, utis.contains( uti ) {
                    MPURLUtils.session.dataTask( with: url, completionHandler: { (data, response, error) in
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

    // MARK: --- CrashlyticsDelegate ---

    func crashlyticsDidDetectReport(forLastExecution report: CLSReport, completionHandler: @escaping (Bool) -> Void) {
        trc( "crashlyticsDidDetectReport: \(report.identifier), on: \(report.crashedOnDate?.description ?? "-"), keys: \(report.customKeys)" )

        DispatchQueue.main.async {
            if let root = UIApplication.shared.keyWindow?.rootViewController {
                let alert = UIAlertController( title: "Issue Detected", message:
                """
                It looks like an unknown issue has caused the app to shut down.
                The issue occurred on:
                \(report.dateCreated)

                To help us address these types of issues quickly, you can submit a fully anonymized report on what went wrong.
                """, preferredStyle: .alert )
                alert.addAction( UIAlertAction( title: "Delete Issue Report", style: .destructive ) { _ in
                    completionHandler( false )
                } )
                alert.addAction( UIAlertAction( title: "Submit Issue Report", style: .default ) { _ in
                    completionHandler( true )
                } )
                alert.preferredAction = alert.actions.last
                root.present( alert, animated: true )
            }
            else {
                mperror( title: "Issue detected", message: report.dateCreated, details: report )
                completionHandler( false )
            }
        }
    }
}
