//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

public enum AppIcon: String, Identifiable, CaseIterable, Sendable {
    case personal = "Personal", enterprise = "Enterprise"

    static let primary = ((
        (Bundle.main.infoDictionary as? NSDictionary)?
            .value(forKeyPath: "CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconName") as? String
    )?.replacingOccurrences(of: "Icon ", with: "")).flatMap(AppIcon.find(named:)) ?? AppIcon.allCases[0]

    static func find(named name: String?) -> Self? {
        .allCases.first { $0.rawValue == name }
    }

    var iconName: String? {
        "Icon \(self.rawValue)"
    }

    var logoName: String {
        "Logo \(self.rawValue)"
    }

    var glyphName: String {
        "Glyph \(self.rawValue)"
    }

    #if TARGET_APP
    #if canImport(UIKit)
    @MainActor
    var isActive: Bool {
        UIApplication.shared.alternateIconName.flatMap { $0 == self.iconName } ?? (self == .primary)
    }

    @MainActor
    func activate() {
        guard UIApplication.shared.supportsAlternateIcons
        else {
            err("Alternative app icons are not supported.")
            return
        }

        UIApplication.shared.setAlternateIconName(self == .primary ? nil : self.iconName) { error in
            if let error {
                err("Couldn't change app icon.", data: error)
            }
            else {
                AppConfig.shared.appIcon = self
            }
        }
    }
    #endif
    #endif
}
