//
// Created by Maarten Billemont on 2019-11-05.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation
import CoreHaptics

public class MPFeedback {
    public static let `shared`: MPFeedback = {
        if #available( iOS 13, * ) {
            return MPHapticFeedback()
        }
        else {
            return MPFeedback()
        }
    }()

    public func play(_ effect: Effect) {
    }

    public enum Effect: Int, CaseIterable {
        case flick, activate, trigger, error
    }
}

@available(iOS 13, *)
public class MPHapticFeedback: MPFeedback {
    private var hapticEngine: CHHapticEngine?
    private var players = [ Effect: CHHapticPatternPlayer ]()

    fileprivate override init() {
        do {
            let hapticEngine = try CHHapticEngine()
            try hapticEngine.start()

            for effect in Effect.allCases {
                switch effect {
                    case .flick:
                        self.players[effect] = try hapticEngine.makePlayer( with: CHHapticPattern( events: [
                            CHHapticEvent( eventType: .hapticTransient, parameters: [
                                CHHapticEventParameter( parameterID: .hapticSharpness, value: .off ),
                                CHHapticEventParameter( parameterID: .hapticIntensity, value: .long ),
                            ], relativeTime: CHHapticTimeImmediate, duration: .immediate ),
                        ], parameters: [] ) )

                    case .activate:
                        self.players[effect] = try hapticEngine.makePlayer( with: CHHapticPattern( events: [
                            CHHapticEvent( eventType: .hapticTransient, parameters: [
                                CHHapticEventParameter( parameterID: .hapticSharpness, value: .off ),
                            ], relativeTime: CHHapticTimeImmediate, duration: .immediate ),
                        ], parameters: [] ) )

                    case .trigger:
                        self.players[effect] = try hapticEngine.makePlayer( with: CHHapticPattern( events: [
                            CHHapticEvent( eventType: .hapticTransient, parameters: [
                                CHHapticEventParameter( parameterID: .hapticSharpness, value: .on ),
                            ], relativeTime: CHHapticTimeImmediate, duration: .immediate ),
                        ], parameters: [] ) )

                    case .error:
                        // TODO
                        self.players[effect] = try hapticEngine.makePlayer( with: CHHapticPattern( events: [
                            CHHapticEvent( eventType: .hapticTransient, parameters: [
                                CHHapticEventParameter( parameterID: .hapticSharpness, value: .on ),
                            ], relativeTime: CHHapticTimeImmediate, duration: .immediate ),
                        ], parameters: [] ) )
                }
            }
            self.hapticEngine = hapticEngine
        }
        catch {
            err( "Haptics not available [>TRC]" )
            pii( "[>] %@", error )

            self.hapticEngine = nil
            self.players.removeAll()
        }
    }

    public override func play(_ effect: Effect) {
        self.hapticEngine?.start { error in
            do {
                if let error = error {
                    throw error
                }
                else {
                    try self.players[effect]?.start( atTime: .immediate )
                }
            }
            catch {
                err( "Couldn't play haptic [>TRC]" )
                pii( "[>] %@", error )
            }
        }
    }
}
