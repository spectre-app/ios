//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import CoreHaptics
import Foundation

public class Feedback {
    public static let shared = Feedback()

    public enum Effect: Int, CaseIterable {
        /// Gesture
        case flick
        /// Interface action
        case activate
        /// Significant action
        case trigger
        /// Alert
        case error
    }

    private var hapticEngine: CHHapticEngine?
    private var players: [Effect: CHHapticPatternPlayer] = [:]

    private init() {
        do {
            let hapticEngine = try CHHapticEngine()
            try hapticEngine.start()

            for effect in Effect.allCases {
                switch effect {
                    case .flick:
                        self.players[effect] = try hapticEngine.makePlayer(
                            with: CHHapticPattern(
                                events: [
                                    CHHapticEvent(
                                        eventType: .hapticTransient,
                                        parameters: [
                                            CHHapticEventParameter(parameterID: .hapticSharpness, value: .off),
                                            CHHapticEventParameter(parameterID: .hapticIntensity, value: .long),
                                        ], relativeTime: CHHapticTimeImmediate, duration: .immediate,
                                    ),
                                ], parameters: [],
                            ))

                    case .activate:
                        self.players[effect] = try hapticEngine.makePlayer(
                            with: CHHapticPattern(
                                events: [
                                    CHHapticEvent(
                                        eventType: .hapticTransient,
                                        parameters: [
                                            CHHapticEventParameter(parameterID: .hapticSharpness, value: .off),
                                        ], relativeTime: CHHapticTimeImmediate, duration: .immediate,
                                    ),
                                ], parameters: [],
                            ))

                    case .trigger:
                        self.players[effect] = try hapticEngine.makePlayer(
                            with: CHHapticPattern(
                                events: [
                                    CHHapticEvent(
                                        eventType: .hapticTransient,
                                        parameters: [
                                            CHHapticEventParameter(parameterID: .hapticSharpness, value: .on),
                                        ], relativeTime: CHHapticTimeImmediate, duration: .immediate,
                                    ),
                                ], parameters: [],
                            ))

                    case .error:
                        // TODO:
                        self.players[effect] = try hapticEngine.makePlayer(
                            with: CHHapticPattern(
                                events: [
                                    CHHapticEvent(
                                        eventType: .hapticTransient,
                                        parameters: [
                                            CHHapticEventParameter(parameterID: .hapticSharpness, value: .on),
                                        ], relativeTime: CHHapticTimeImmediate, duration: .immediate,
                                    ),
                                ], parameters: [],
                            ))
                }
            }
            self.hapticEngine = hapticEngine
        }
        catch {
            wrn("Haptics not available.", data: error)

            self.hapticEngine = nil
            self.players.removeAll()
        }
    }

    public func play(_ effect: Effect) {
        self.hapticEngine?.start { error in
            do {
                if let error {
                    throw error
                }
                else {
                    try self.players[effect]?.start(atTime: .immediate)
                }
            }
            catch {
                err("Couldn't play haptic.", data: error)
            }
        }
    }
}
