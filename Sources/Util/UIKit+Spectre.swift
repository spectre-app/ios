//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

//import SafariServices
//import UIKit

// extension SFSafariViewController: ThemeObserver {
//    convenience init(url: URL) {
//        self.init( url: url, configuration: Configuration() )
//
//        self.dismissButtonStyle = .close
//        self.modalPresentationStyle = .pageSheet
//
//        Theme.current.observers.register( observer: self )?
//             .didChange( theme: Theme.current )
//    }
//
//    // MARK: - ThemeObserver
//
//    func didChange(theme: Theme) {
//        self.preferredBarTintColor = theme.color.backdrop.get(forTraits: self.traitCollection)
//        self.preferredControlTintColor = theme.color.tint.get(forTraits: self.traitCollection)
//    }
// }
