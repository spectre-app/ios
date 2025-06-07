//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import SwiftUI
import WrappingHStack

struct LogScreen: View {
    @EnvironmentObject
    private var config: AppConfig
    @Environment(\.reportMemoryLeaks)
    private var reportMemoryLeaks
    @State
    private var logLevel = LogSink.shared.level
    @State
    private var logMessages = ""

    @State
    private var deviceIdentifier = Tracker.shared.identifierForDevice
    @State
    private var ownerIdentifier = Tracker.shared.identifierForOwner

    var body: some View {
        Form {
            Section {
                LabeledContent("Shut down the application and report on remaining leaked memory objects.") {
                    VStack {
                        Toggle("Memory Profiler", systemImage: "doc.text.magnifyingglass", isOn: self.$config.memoryProfiler)

                        Button("Report Leaks") {
                            self.reportMemoryLeaks()
                        }
                        .disabled(!self.config.memoryProfiler)
                    }
                }
            }

            Section("Logbook") {
                TextArea(text: .constant(self.logMessages))
                    .multilineTextAlignment(.leading)
                    .lineLimit(15)
                    .font(.spectre.caption2)

                LabeledContent(
                    """
                    Show only messages at the selected level or higher.
                    Debug and trace messages are not recorded unless the level is set accordingly.
                    """
                ) {
                    VStack {
                        Button("Copy Logs") {
                            UIPasteboard.general.setObjects(
                                [self.logMessages as NSString],
                                localOnly: AppFeature.handoff.isEnabled, expirationDate: nil
                            )
                        }

                        Picker("Log Level", selection: self.$logLevel) {
                            ForEach(type(of: self.logLevel).allCases) { level in
                                Text(level.description)
                            }
                        }
                    }
                }
            }

            Section("Identity") {
                LabeledContent(self.deviceIdentifier) {
                    Button("Copy Anonymous Device Identifier") {
                        UIPasteboard.general.setObjects(
                            [self.deviceIdentifier as NSString],
                            localOnly: AppFeature.handoff.isEnabled, expirationDate: nil
                        )
                    }
                }

                LabeledContent(self.ownerIdentifier) {
                    Button("Copy Anonymous Owner Identifier") {
                        UIPasteboard.general.setObjects(
                            [self.ownerIdentifier as NSString],
                            localOnly: AppFeature.handoff.isEnabled, expirationDate: nil
                        )
                    }
                }
            }
        }
        .labeledContentStyle(.spectreCaptioned)
        .multilineTextAlignment(.center)
        .task(id: self.logLevel) {
            self.logMessages = await LogSink.shared.enumerate(level: self.logLevel).joined(separator: "\n")
        }

        // Behaviour
        .popoverTitle(productName)
    }
}

#if DEBUG
#Preview {
    Path().popoverForm(isPresented: .constant(true)) {
        LogScreen()
    }
    .spectreStyle()
}
#endif
