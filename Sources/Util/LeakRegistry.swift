//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import SwiftUI

class LeakRegistry: LeakObserver {
    static let shared = LeakRegistry()

    let observers = Observers<LeakObserver>()
    var isSuspended = false
    private let semaphore = DispatchQueue(label: "LeakRegistry")
    private var members: [ObjectIdentifier: Registration] = [:]
    private var isEnabled: Bool { UserDefaults.shared.bool(forKey: "memoryProfiler") }

    init() {
        self.observers.register(observer: self)
    }

    @discardableResult
    func register<O: AnyObject>(_ value: O) -> O {
        self.semaphore.sync {
            if self.isEnabled {
                self.members[ObjectIdentifier(value)] = Registration(value: value)
            }

            return value
        }
    }

    func setDebugging(_ value: AnyObject) {
        self.semaphore.sync {
            self.members[ObjectIdentifier(value)]?.isDebugging = true
        }
    }

    @discardableResult
    func unregister<O: AnyObject>(_ value: O) -> O {
        self.semaphore.sync {
            self.members[ObjectIdentifier(value)] = nil
            return value
        }
    }

    func reportLeaks() -> String {
        self.observers.notify { $0.willReportLeaks() }

        return self.semaphore.sync {
            var report = String(format: "Monitored Objects: %d\n", self.members.count)
            report += String(format: "Memory Remaining: %0.3f Mb\n", Double(self.availableMemory) / 1024 / 1024)

            var released: [String: [Registration]] = [:]
            var leaked: [String: [Registration]] = [:], leaks = 0
            for member in self.members.values {
                if member.value == nil {
                    released[member.shortType, defaultSet: []].append(member)
                }
                else {
                    leaked[member.shortType, defaultSet: []].append(member)
                    leaks += 1
                }
            }

            if leaked.isEmpty {
                report += "\n\nNO LEAKS :-)\n"
            }
            else {
                report += "\n\n\(leaks) LEAKED OBJECTS:\n"
                report += "==================\n"
                for (type, members) in leaked.sorted(by: { $0.key < $1.key }) {
                    report += String(
                        format: "%dx %@ %@\n", members.count, type,
                        String(repeating: "*", count: members.filter(\.isDebugging).count),
                    )
                }

                report += "\nLEAK DETAILS:\n"
                report += "-------------\n"
                for (_, members) in leaked.sorted(by: { $0.key < $1.key }) {
                    for member in members.sorted(by: { $0.registered < $1.registered }) {
                        report += String(format: (member.isDebugging ? "*" : "-") + " [%@] %@\n", member.detailType, member.description)
                    }
                }
            }

            if !released.isEmpty {
                report += "\n\nReleased Objects:\n"
                report += "=================\n"
                for (type, members) in released.sorted(by: { $0.key < $1.key }) {
                    report += String(
                        format: "%dx %@ %@\n", members.count, type,
                        String(repeating: "*", count: members.filter(\.isDebugging).count),
                    )
                }
            }

            return report
        }
    }

    private var availableMemory: UInt64 {
        #if canImport(UIKit)
        UInt64(os_proc_available_memory())
        #else
        ProcessInfo.processInfo.physicalMemory
        #endif
    }

    // MARK: - LeakObserver

    func willReportLeaks() {}

    func shouldCancelOperations() {
        self.isSuspended = true
        //        #if TARGET_APP
        //        SitePreview.linkPreview.unset()
        //        #endif
        URLSession.required.clear()
        URLSession.optional.clear()
    }

    struct Registration: CustomStringConvertible {
        weak var value: AnyObject?
        var isDebugging: Bool
        let shortType: String
        let detailType: String
        let description: String
        let registered = Date()

        init(value: AnyObject) {
            self.value = value
            #if DEBUG
            self.isDebugging = isDebuggingObject(value)
            #else
            self.isDebugging = false
            #endif
            self.shortType = _describe(Swift.type(of: value), details: false)
            self.detailType = _describe(Swift.type(of: value), details: true)
            self.description = value.debugDescription
        }
    }
}

extension EnvironmentValues {
    var reportMemoryLeaks: () -> Void {
        get { self[ReportMemoryLeaksKey.self] }
        set { self[ReportMemoryLeaksKey.self] = newValue }
    }

    private struct ReportMemoryLeaksKey: EnvironmentKey {
        static let defaultValue: () -> Void = {}
    }
}

struct LeakReporter: ViewModifier {
    @State
    private var isReportingMemoryLeaks = false

    func body(content: Content) -> some View {
        if self.isReportingMemoryLeaks {
            LeaksScreen()
        }
        else {
            content.environment(\.reportMemoryLeaks) { self.isReportingMemoryLeaks = true }
        }
    }

    private struct LeaksScreen: View {
        @State
        private var report = LeakRegistry.shared.reportLeaks()
        @State
        private var background: Color = .red

        var body: some View {
            ScrollView {
                Text(verbatim: self.report)
                    .multilineTextAlignment(.leading)
            }
            .safeAreaInset(edge: .bottom) {
                ControlGroup {
                    Button("Refresh", action: self.update)
                    Button("Clean", action: self.clean)
                }
            }
            .background(self.background, ignoresSafeAreaEdges: .all)
        }

        private func update() {
            self.background = .red

            DispatchQueue.main.async {
                self.report = LeakRegistry.shared.reportLeaks()
                self.background = .green
            }
        }

        private func clean() {
            self.background = .yellow

            DispatchQueue.main.async {
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
