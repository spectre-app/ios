//
// Created by Maarten Billemont on 2022-05-25.
// Copyright (c) 2022 Lyndir. All rights reserved.
//

import Foundation

class LeakRegistry: LeakObserver, AppConfigObserver {
    static let shared = LeakRegistry()

    let observers = Observers<LeakObserver>()
    private let semaphore = DispatchQueue( label: "LeakRegistry" )
    private var members   = [ ObjectIdentifier: Registration ]()

    init() {
        self.observers.register( observer: self )
        AppConfig.shared.observers.register( observer: self )?.didChange( appConfig: AppConfig.shared, at: \.memoryProfiler )
    }

    @discardableResult
    func register<O: AnyObject>(_ value: O) -> O {
        self.semaphore.sync {
            if AppConfig.shared.memoryProfiler {
                self.members[ObjectIdentifier( value )] = Registration( value: value )
            }
            return value
        }
    }

    func setDebugging(_ value: AnyObject) {
        self.semaphore.sync {
            self.members[ObjectIdentifier( value )]?.isDebugging = true
        }
    }

    @discardableResult
    func unregister<O: AnyObject>(_ value: O) -> O {
        self.semaphore.sync {
            self.members[ObjectIdentifier( value )] = nil
            return value
        }
    }

    func reportViewController() -> UIViewController {
        ViewController()
    }

    func reportLeaks() -> String {
        self.observers.notify { $0.willReportLeaks() }

        return self.semaphore.sync {
            var report = String(format: "Monitored Objects: %d\n", self.members.count)
            report += String(format: "Memory Remaining: %0.3f Mb\n", Double(os_proc_available_memory()) / 1024 / 1024 )

            var released = [ String: [ Registration ] ]()
            var leaked   = [ String: [ Registration ] ](), leaks = 0
            for member in self.members.values {
                if member.value == nil {
                    released[member.shortType, defaultSet: []].append( member )
                }
                else {
                    leaked[member.shortType, defaultSet: []].append( member )
                    leaks += 1
                }
            }

            if leaked.isEmpty {
                report += "\n\nNO LEAKS :-)\n"
            } else {
                report += "\n\n\(leaks) LEAKED OBJECTS:\n"
                report += "==================\n"
                for (type, members) in leaked.sorted(by: { $0.key < $1.key }) {
                    report += String( format: "%dx %@ %@\n", members.count, type,
                                      String( repeating: "*", count: members.filter { $0.isDebugging }.count ) )
                }

                report += "\nLEAK DETAILS:\n"
                report += "-------------\n"
                for (_, members) in leaked.sorted(by: { $0.key < $1.key }) {
                    for member in members.sorted( by: { $0.registered < $1.registered } ) {
                        report += String(format: (member.isDebugging ? "*" : "-") + " [%@] %@\n", member.detailType, member.description )
                    }
                }
            }

            if !released.isEmpty {
                report += "\n\nReleased Objects:\n"
                report += "=================\n"
                for (type, members) in released.sorted(by: { $0.key < $1.key }) {
                    report += String(format: "%dx %@ %@\n", members.count, type,
                                     String( repeating: "*", count: members.filter { $0.isDebugging }.count ) )
                }
            }

            return report
        }
    }

    // MARK: - AppConfigObserver

    func didChange(appConfig: AppConfig, at change: PartialKeyPath<AppConfig>) {
        if change == \.memoryProfiler {
            if appConfig.memoryProfiler {
                inf( "Will start tracing memory usage." )
            }
        }
    }

    // MARK: - LeakObserver

    func willReportLeaks() {}

    func shouldCancelOperations() {
        AppConfig.shared.isEnabled = false
        URLSession.required.unset()
        URLSession.optional.unset()
    }

    struct Registration: CustomStringConvertible {
        weak var value: AnyObject?
        var isDebugging: Bool
        let shortType:   String
        let detailType:  String
        let description: String
        let registered = Date()

        init(value: AnyObject) {
            self.value = value
            #if DEBUG
            self.isDebugging = isDebuggingObject(value)
            #else
            self.isDebugging = false
            #endif
            self.shortType = _describe( Swift.type( of: value ), typeDetails: false )
            self.detailType = _describe( Swift.type( of: value ), typeDetails: true )
            self.description = value.debugDescription
        }
    }

    private class ViewController: UIViewController {
        let textView      = UITextView()
        let refreshButton = UIButton(type: .roundedRect)
        let cleanButton = UIButton(type: .roundedRect)

        override func loadView() {
            self.view = using(UIStackView( arrangedSubviews: [
                self.textView,
                UIStackView( arrangedSubviews: [ self.refreshButton, self.cleanButton ], distribution: .fillEqually )
            ], axis: .vertical, spacing: 8 )) {
                $0.isLayoutMarginsRelativeArrangement = true
            }
            self.view.backgroundColor = .red

            self.textView.font = UIFont.monospacedSystemFont( ofSize: UIFont.systemFontSize, weight: .medium )

            self.refreshButton.setTitleColor(.black, for: .normal)
            self.refreshButton.setTitle( "Refresh Report", for: .normal )
            self.refreshButton.addTarget( self, action: #selector( update ), for: .primaryActionTriggered )
            self.cleanButton.setTitleColor(.black, for: .normal)
            self.cleanButton.setTitle( "Cancel Operations", for: .normal )
            self.cleanButton.addTarget( self, action: #selector( clean ), for: .primaryActionTriggered )
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear( animated )

            self.update()
        }

        override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            if event?.type == .motion, motion == .motionShake {
                self.update()
            }
            else {
                super.motionEnded( motion, with: event )
            }
        }

        @objc
        func update() {
            self.view.backgroundColor = .red

            DispatchQueue.main.perform(deadline: .now() + .seconds(1)) {
                self.textView.text = LeakRegistry.shared.reportLeaks()
                self.view.backgroundColor = .green
            }
        }

        @objc
        func clean() {
            self.view.backgroundColor = .yellow

            OperationQueue.main.addOperation {
                LeakRegistry.shared.observers.notify { $0.shouldCancelOperations() }
                self.update()
            }
        }
    }
}

protocol LeakObserver {
    func willReportLeaks()
    func shouldCancelOperations()
}
