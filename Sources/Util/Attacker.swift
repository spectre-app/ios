// =============================================================================
// Created by Maarten Billemont on 2019-11-01.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import Foundation

enum Hash {
    case bcrypt10, spectre
}

enum Rig {
    case gtx1080ti

    func attempts_per_second(for hash: Hash) -> Decimal {
        switch self {
            case .gtx1080ti:
                // https://gist.github.com/epixoip/ace60d09981be09544fdd35005051505
                switch hash {
                    case .bcrypt10:
                        return Decimal( 722 ) // H/s
                    case .spectre:
                        return Decimal( 168 ) // H/s
                }
        }
    }

    var cost_fixed: Decimal {
        switch self {
            case .gtx1080ti:
                return Decimal( 1200 ) // $
        }
    }

    var cost_watt: Decimal {
        switch self {
            case .gtx1080ti:
                return Decimal( 250 ) // W
        }
    }

    var cost_per_kwh: Decimal {
        switch self {
            case .gtx1080ti:
                return Decimal( 0.15 ) // $/kWh
        }
    }
}

enum Attacker: Int, CaseIterable, CustomStringConvertible {
    static let `default` = Attacker.private

    case single, `private`, corporate, state

    var description:          String {
        switch self {
            case .single:
                return "single"
            case .private:
                return "private"
            case .corporate:
                return "corporate"
            case .state:
                return "state"
        }
    }
    var localizedDescription: String {
        "\(number: self.scale, as: "0.#") x \(number: Rig.gtx1080ti.attempts_per_second( for: .bcrypt10 ), .abbreviated)/s " +
                "(~ \(number: self.fixed_budget, locale: .C, .currency, .abbreviated) + \(number: self.monthly_budget, .currency, .abbreviated)/m)"
    }
    var rig:                  Rig {
        .gtx1080ti
    }
    var fixed_budget:         Decimal {
        switch self {
            case .single:
                return self.rig.cost_fixed

            case .private:
                return 5_000

            case .corporate:
                return 20_000_000

            case .state:
                return 5_000_000_000.0
        }
    }
    var monthly_budget:       Decimal {
        (self.scale * self.rig.cost_watt / 1000) * 24 * 30 * self.rig.cost_per_kwh
    }

    /// The hardware scale that the attacker employs to attack a hash.
    var scale:                Decimal {
        self.fixed_budget / self.rig.cost_fixed
    }

    static func named(_ identifier: String) -> Attacker {
        Attacker.allCases.first { $0.description == identifier } ?? .private
    }

    static func permutations(type: SpectreResultType) -> Decimal? {
        guard type.in( class: .template )
        else { return nil }

        var count     = 0
        let templates = UnsafeBufferPointer( start: spectre_type_templates( type, &count ), count: count )
        defer { templates.deallocate() }

        var typePermutations: Decimal = 0
        for template in templates {
            guard let template = template
            else { continue }

            var templatePermutations: Decimal = 1
            for c in 0..<strlen( template ) {
                templatePermutations *= Decimal( strlen( spectre_class_characters( template[c] ) ) )
            }

            typePermutations += templatePermutations
        }

        return typePermutations
    }

    static func entropy(type: SpectreResultType) -> Int? {
        self.permutations( type: type ).flatMap { self.entropy( permutations: $0 ) }
    }

    func timeToCrack(type: SpectreResultType, hash: Hash = .bcrypt10) -> TimeToCrack? {
        Attacker.permutations( type: type ).flatMap { self.timeToCrack( permutations: $0, hash: hash ) }
    }

    static func permutations(string: String?) -> Decimal? {
        guard var string = string, let dictionary = dictionary
        else { return nil }

        var stringPermutations: Decimal = 1

        for word in dictionary {
            let newString = string.replacingOccurrences( of: word, with: "" )
            if newString != string {
                stringPermutations *= Decimal( dictionary.count )
                string = newString
            }
        }

        var previousCharacter: Int32 = 0
        for passwordCharacter in string.utf8CString.map( Int32.init ) {
            defer {
                previousCharacter = passwordCharacter
            }

            // Skip terminator and repeating characters.
            if passwordCharacter == 0 || abs( passwordCharacter - previousCharacter ) < 2 {
                continue
            }

            var characterEntropy: Decimal = 256 /* a byte */
            for characterClass in [ "v", "c", "a", "n", "x" ] {
                guard let charactersForClass = spectre_class_characters( characterClass.utf8CString[0] )
                else { continue }

                if (strchr( charactersForClass, passwordCharacter )) != nil {
                    // Found class for password character.
                    characterEntropy = Decimal( strlen( charactersForClass ) )
                    break
                }
            }

            stringPermutations *= characterEntropy
        }

        return stringPermutations
    }

    static func entropy(string: String?) -> Int? {
        self.permutations( string: string ).flatMap { self.entropy( permutations: $0 ) }
    }

    func timeToCrack(string: String?, hash: Hash = .bcrypt10) -> TimeToCrack? {
        Attacker.permutations( string: string ).flatMap { self.timeToCrack( permutations: $0, hash: hash ) }
    }

    static func entropy(permutations: Decimal) -> Int {
        Int( truncating: permutations.log( base: 2 ).rounded( 0, .down ) as NSNumber )
    }

    func timeToCrack(permutations: Decimal, hash: Hash = .bcrypt10) -> TimeToCrack {

        // Amount of seconds to search half the permutations (average hit chance)
        var secondsToCrack = (permutations / 2) / self.rig.attempts_per_second( for: hash )

        // The search scale employed by the attacker.
        secondsToCrack /= self.scale

        // Convert seconds into other time scales.
        return TimeToCrack( permutations: permutations, attacker: self, period: .seconds( secondsToCrack ) )
    }
}

struct TimeToCrack: CustomStringConvertible {
    var permutations: Decimal
    var attacker:     Attacker
    var period:       Period

    var description: String {
        // swiftlint:disable:next identifier_name
        let Wh   = (self.attacker.scale * self.attacker.rig.cost_watt) * self.period.seconds / 3600
        let cost = (self.attacker.scale * self.attacker.rig.cost_fixed) + self.attacker.rig.cost_per_kwh * Wh / 1000
        if self.period.seconds < 2 {
            return "trivial"
        }

        let normalizedPeriod = self.period.normalize
        if case Period.universes = normalizedPeriod {
            return normalizedPeriod.localizedDescription
        }
        return "~\(normalizedPeriod.localizedDescription) & " +
                "~\(number: cost, locale: .C, .currency, .abbreviated), " +
                "~\(number: Wh, .abbreviated)Wh"
    }
}
