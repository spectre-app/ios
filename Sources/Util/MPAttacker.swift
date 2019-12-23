//
// Created by Maarten Billemont on 2019-11-01.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

/* An Nvidia GTX 1080 Ti (250W) calculates ~20273 bcrypt-5 hashes per second @ ~490$ -> 21 H/$ */
/* An GeForce GTX 1050 Ti (75W) calculates ~4104 bcrypt-5 hashes per second @ ~160$ -> 25 H/$ */
/* An GeForce GTX 980 Ti (250W) calculates ~12306 bcrypt-5 hashes per second @ ~480$ -> 25 H/$ */
/* An Nvidia GTX 1060 (120W) calculates ~7800 bcrypt-5 hashes per second @ ~310$ -> 25 H/$ */
let attempts_per_second = Decimal( 7800 ) // H/s
let cost_fixed          = Decimal( 310 ) // $
let cost_watt           = Decimal( 120 ) // W
let cost_per_kwh        = Decimal( 0.1 ) // $/kWh

enum MPAttacker: Int, CaseIterable, CustomStringConvertible {
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
        "\(self.scale, numeric: "0.#") x \(amount: attempts_per_second)/s (~ \(amount: self.fixed_budget)$ HW + \(amount: self.monthly_budget)$/m)"
    }
    var fixed_budget:         Decimal {
        switch self {
            case .single:
                return cost_fixed

            case .private:
                return 5_000

            case .corporate:
                return 20_000_000

            case .state:
                return 5_000_000_000.0
        }
    }
    var monthly_budget:       Decimal {
        (self.scale * cost_watt / 1000) * 24 * 30 * cost_per_kwh
    }

    /// The hardware scale that the attacker employs to attack a hash.
    var scale:                Decimal {
        self.fixed_budget / cost_fixed
    }

    static func `for`(_ identifier: String) -> MPAttacker {
        for attacker in MPAttacker.allCases {
            if attacker.description == identifier {
                return attacker
            }
        }

        return .private
    }

    static func permutations(type: MPResultType) -> Decimal? {
        guard type.in( class: .template )
        else { return nil }

        var count = 0
        guard let templates = mpw_type_templates( type, &count )
        else { return nil }
        defer { templates.deallocate() }

        var typePermutations = Decimal( 0 )
        for t in 0..<count {
            guard let template = templates[t]
            else { continue }

            var templatePermutations = Decimal( 1 )
            for c in 0..<strlen( template ) {
                templatePermutations *= Decimal( strlen( mpw_class_characters( template[c] ) ) )
            }

            typePermutations += templatePermutations
        }

        return typePermutations
    }

    static func entropy(type: MPResultType) -> Int? {
        self.permutations( type: type ).flatMap { self.entropy( permutations: $0 ) }
    }

    func timeToCrack(type: MPResultType) -> TimeToCrack? {
        MPAttacker.permutations( type: type ).flatMap { self.timeToCrack( permutations: $0 ) }
    }

    static func permutations(string: String?) -> Decimal? {
        guard let string = string
        else { return nil }

        var stringPermutations = Decimal( 1 )

        for passwordCharacter in string.utf8CString {
            var characterEntropy = Decimal( 256 ) /* a byte */

            for characterClass in [ "v", "c", "a", "x" ] {
                guard let charactersForClass = mpw_class_characters( characterClass.utf8CString[0] )
                else { continue }

                if (strchr( charactersForClass, Int32( passwordCharacter ) )) != nil {
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

    func timeToCrack(string: String?) -> TimeToCrack? {
        MPAttacker.permutations( string: string ).flatMap { self.timeToCrack( permutations: $0 ) }
    }

    static func entropy(permutations: Decimal) -> Int {
        Int( truncating: permutations.log( base: 2 ) as NSNumber )
    }

    func timeToCrack(permutations: Decimal) -> TimeToCrack {

        // Amount of seconds to search half the permutations (average hit chance)
        var secondsToCrack = (permutations / 2) / attempts_per_second

        // The search scale employed by the attacker.
        secondsToCrack /= self.scale

        // Convert seconds into other time scales.
        var time = TimeToCrack( permutations: permutations, attacker: self )
        time.inSeconds = secondsToCrack
        time.inHours = time.inSeconds / 3600
        time.inDays = time.inHours / 24
        time.inWeeks = time.inDays / 7
        time.inMonths = time.inDays / 30
        time.inYears = time.inDays / 356
        time.inUniverses = time.inYears / 14_000_000_000.0

        return time
    }
}

struct TimeToCrack: CustomStringConvertible {
    var permutations: Decimal
    var attacker:     MPAttacker
    var inSeconds:    Decimal = 0
    var inHours:      Decimal = 0
    var inDays:       Decimal = 0
    var inWeeks:      Decimal = 0
    var inMonths:     Decimal = 0
    var inYears:      Decimal = 0
    var inUniverses:  Decimal = 0

    var description: String {
        let kWh  = (self.attacker.scale * cost_watt) * self.inHours / 1000
        let cost = (self.attacker.scale * cost_fixed) + cost_per_kwh * kWh

        if self.inUniverses > 1 {
            return "> age of the universe"
        }
        else if self.inYears > 1 {
            return "~\(self.inYears, numeric: "#,##0.#") years, ~\(amount: cost)$"
        }
        else if self.inMonths > 1 {
            return "\(self.inMonths, numeric: "#,##0.#") months, ~\(amount: cost)$"
        }
        else if self.inWeeks > 1 {
            return "\(self.inWeeks, numeric: "#,##0.#") weeks, ~\(amount: cost)$"
        }
        else if self.inDays > 1 {
            return "\(self.inDays, numeric: "#,##0.#") days, ~\(amount: cost)$"
        }
        else if self.inHours > 1 {
            return "\(self.inHours, numeric: "#,##0.#") hours, ~\(amount: cost)$"
        }
        else if self.inSeconds > 2 {
            return "\(self.inSeconds, numeric: "#,##0.#") seconds, ~\(amount: cost)$"
        }

        return "trivial"
    }
}
