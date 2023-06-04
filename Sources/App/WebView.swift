//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import SafariServices
import SwiftUI

struct WebView: UIViewControllerRepresentable {
    let url:     URL
    var dismiss: ((SFSafariViewController) -> Void)?

    func makeCoordinator() -> WebDelegate {
        WebDelegate()
    }

    func makeUIViewController(context: Context) -> SFSafariViewController {
        using(SFSafariViewController(url: self.url, configuration: context.coordinator.configuration)) {
            $0.delegate = context.coordinator
        }
    }

    func updateUIViewController(_ viewController: SFSafariViewController, context: Context) {
        context.coordinator.view = self
    }

    class WebDelegate: NSObject, SFSafariViewControllerDelegate {
        let configuration: SFSafariViewController.Configuration = .init()
        var view: WebView?

        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            if let dismiss = self.view?.dismiss {
                dismiss(controller)
            }
            else if let navigationController = controller.navigationController {
                navigationController.popViewController(animated: true)
            }
        }
    }
}

#if DEBUG
#Preview("WebView") {
    WebView(url: URL(string: "https://spectre.pw")!, dismiss: nil)
        .spectreStyle()
}
#endif
