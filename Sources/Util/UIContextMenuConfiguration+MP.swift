//
// Created by Maarten Billemont on 2019-11-16.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

@available(iOS 13, *)
extension UIContextMenuConfiguration {
    var indexPath: IndexPath? {
        self.identifier as? IndexPath
    }
    var action: UIAction? {
        get {
            objc_getAssociatedObject( self, &Key.action ) as? UIAction
        }
        set {
            objc_setAssociatedObject( self, &Key.action, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN )
        }
    }

    convenience init(indexPath: IndexPath,
                     previewProvider: ((UIContextMenuConfiguration) -> UIViewController?)? = nil,
                     actionProvider: (([UIMenuElement], UIContextMenuConfiguration) -> UIMenu?)? = nil) {
        var previewProvider = PreviewProvider( provider: previewProvider )
        var actionProvider  = ActionProvider( provider: actionProvider )
        self.init( identifier: indexPath as NSIndexPath,
                   previewProvider: { previewProvider.provide() },
                   actionProvider: { actionProvider.provide( $0 ) } )
        previewProvider.configuration = self
        actionProvider.configuration = self
    }

    // MARK: --- Types ---

    private struct Key {
        static var action = 0
    }
}

@available(iOS 13, *)
fileprivate struct PreviewProvider {
    let provider:      ((UIContextMenuConfiguration) -> UIViewController?)?
    var configuration: UIContextMenuConfiguration?

    func provide() -> UIViewController? {
        self.configuration.flatMap { self.provider?( $0 ) }
    }
}

@available(iOS 13, *)
fileprivate struct ActionProvider {
    let provider:      (([UIMenuElement], UIContextMenuConfiguration) -> UIMenu?)?
    var configuration: UIContextMenuConfiguration?

    func provide(_ elements: [UIMenuElement]) -> UIMenu? {
        self.configuration.flatMap { self.provider?( elements, $0 ) }
    }
}
