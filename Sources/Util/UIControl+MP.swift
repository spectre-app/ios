//
// Created by Maarten Billemont on 2019-11-09.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

extension UIControl {
    private struct Key {
        static var actionHandlers = 0
    }

    @objc
    var actionHandlers: [UIControlHandler] {
        get {
            objc_getAssociatedObject( self, &Key.actionHandlers ) as? [UIControlHandler] ?? []
        }
        set {
            objc_setAssociatedObject( self, &Key.actionHandlers, newValue, .OBJC_ASSOCIATION_RETAIN )
        }
    }

    @discardableResult
    func action(for controlEvents: UIControl.Event, _ action: @escaping (UIEvent) -> Void) -> UIControlHandler {
        let handler = UIControlHandler( handler: action )
        self.actionHandlers.append( handler )
        self.addTarget( handler, action: #selector( UIControlHandler.action ), for: controlEvents )

        return handler
    }

    @discardableResult
    func action(for controlEvents: UIControl.Event, _ action: @escaping () -> Void) -> UIControlHandler {
        let handler = UIControlHandler( handler: action )
        self.actionHandlers.append( handler )
        self.addTarget( handler, action: #selector( UIControlHandler.action ), for: controlEvents )

        return handler
    }
}

public class UIControlHandler: NSObject {
    private let eventHandler: ((UIEvent) -> Void)?
    private let voidHandler:  (() -> Void)?

    public init(handler: @escaping (UIEvent) -> Void) {
        self.eventHandler = handler
        self.voidHandler = nil
    }

    public init(handler: @escaping () -> Void) {
        self.eventHandler = nil
        self.voidHandler = handler
    }

    @objc
    func action(_ sender: UIControl, _ event: UIEvent) {
        self.eventHandler?( event )
        self.voidHandler?()
    }
}
