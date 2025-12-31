//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import SwiftUI

// private let tipsView     = TipsView( tips: [
//    // App
//    "Welcome\(AppConfig.shared.runCount <= 1 ? "" : " back") to Spectre!",
//    "Spectre is 100% open source \(.icon( "osi" )) and Free Software.",
//    "Leave no traces by using incognito \(.icon( "user-secret" )) mode.",
//    "With Diagnostics \(.icon( "briefcase-medical" )), we can build you the best app.",
//    "Be reachable for emergency security alerts \(.icon( "bell-exclamation" )).",
//    "Personalize your app with our \(Theme.allCases.count) custom-made themes \(.icon( "brush" )).",
//    "Premium \(.icon( "user-tie" )) subscribers make this app possible.",
//    "Shake \(.icon( "mobile" )) for logs and advanced settings.",
//    "Join the discussion \(.icon( "comments" )) in the Spectre Community.",
//    "While in Offline Mode \(.icon( "wifi-slash" )), Spectre disables any features that use the Internet.",
//    "Prefer a more consistent monochrome look? Try turning off Colorful Sites \(.icon( "paint-brush" )).",
//    // User
//    "Your identicon ╚☻╯⛄ helps you spot typos.",
//    "Long press your user's initials button to sign out quickly \(.icon( "arrow-up-left-from-circle" )).",
//    "Set your user's Standard Login \(.icon( "circle-user" )), usually your e-mail.",
//    "For extra security, set your user's Default Password to max \(.icon( "dial-max" )).",
//    "Worried about an attack? Set a Defense Strategy \(.icon( "shield" )).",
//    "Turn on Masked •••• passwords to deter shoulder-snooping.",
//    "Enable AutoFill \(.icon( "keyboard" )) to use Spectre from other apps.",
//    "Biometric \(.icon( KeychainKeyFactory.factor.iconName ?? KeychainKeyFactory.Factor.biometricTouch.iconName )) login is the quickest way to sign in.",
//    "File Sharing \(.icon( "file-export" )) makes your user's export file available from iTunes or the Files app.",
//    // Site
//    "Long press a site to quickly perform an action or open the site in a browser \(.icon( "globe" )).",
//    "Long press a site's mode (\(.icon( "key" ))/\(.icon( "id-card-clip" ))/\(.icon( "comments-question-check" ))) to configure it.",
//    "Increment your site's counter \(.icon( "caret-up" )) if its password is compromised.",
//    "Site doesn't accept your password? Try a different Type.",
//    "Defense Strategy shows password time-to-crack \(.icon( "shield-slash" )) if attacked.",
//    "Use Security Answers \(.icon( "comments-question-check" )) to avoid divulging private information.",
//    "Sites are automatically styled \(.icon( "paint-brush" )) from their home page.",
// ], first: 0, random: false )

struct SpectreTipsView: View {
    var body: some View {
        Text("Your identicon ╚☻╯⛄ helps you spot typos.")
            .foregroundColor(.spectre.alternative)
            .font(.spectre.caption2)
    }
}

struct SpectreTipsView_Previews: PreviewProvider {
    static var previews: some View {
        SpectreTipsView()
    }
}
