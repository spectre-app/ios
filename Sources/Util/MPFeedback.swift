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
        case flick, activate, trigger
    }
}

@available(iOS 13.0, *)
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
                                CHHapticEventParameter( parameterID: .hapticSharpness, value: 0 ),
                                CHHapticEventParameter( parameterID: .hapticIntensity, value: 0.618 ),
                            ], relativeTime: CHHapticTimeImmediate, duration: 0 ),
                        ], parameters: [] ) )

                    case .activate:
                        self.players[effect] = try hapticEngine.makePlayer( with: CHHapticPattern( events: [
                            CHHapticEvent( eventType: .hapticTransient, parameters: [
                                CHHapticEventParameter( parameterID: .hapticSharpness, value: 0 ),
                            ], relativeTime: CHHapticTimeImmediate, duration: 0 ),
                        ], parameters: [] ) )

                    case .trigger:
                        self.players[effect] = try hapticEngine.makePlayer( with: CHHapticPattern( events: [
                            CHHapticEvent( eventType: .hapticTransient, parameters: [
                                CHHapticEventParameter( parameterID: .hapticSharpness, value: 1 ),
                            ], relativeTime: CHHapticTimeImmediate, duration: 0 ),
                        ], parameters: [] ) )
                }
            }
            self.hapticEngine = hapticEngine
        }
        catch {
            err( "Haptics not available [>TRC]" )
            trc( "\(error)" )

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
                    try self.players[effect]?.start( atTime: 0 )
                }
            }
            catch {
                err( "Couldn't play haptic [>TRC]" )
                trc( "\(error)" )
            }
        }
    }
}
