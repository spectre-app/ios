//==============================================================================
// Created by Maarten Billemont on 2019-11-05.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
//==============================================================================

import Foundation
import CoreHaptics

public class Feedback {
    public static let `shared`: Feedback = {
        if #available( iOS 13, * ) {
            return HapticFeedback()
        }
        else {
            return Feedback()
        }
    }()

    public func play(_ effect: Effect) {
    }

    public enum Effect: Int, CaseIterable {
        case flick, activate, trigger, error
    }
}

@available( iOS 13, * )
public class HapticFeedback: Feedback {
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
