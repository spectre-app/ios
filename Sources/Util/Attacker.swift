//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

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
                    case .bcrypt10: Decimal(722) // H/s
                    case .spectre: Decimal(168) // H/s
                }
        }
    }

    var cost_fixed: Decimal {
        switch self {
            case .gtx1080ti: Decimal(1200) // $
        }
    }

    var cost_watt: Decimal {
        switch self {
            case .gtx1080ti: Decimal(250) // W
        }
    }

    var cost_per_kwh: Decimal {
        switch self {
            case .gtx1080ti: Decimal(0.15) // $/kWh
        }
    }
}

enum Attacker: Int, CaseIterable, CustomStringConvertible, Identifiable {
    static let `default` = Attacker.private

    case single, `private`, corporate, state

    var description:          String {
        switch self {
            case .single: "single"
            case .private: "private"
            case .corporate: "corporate"
            case .state: "state"
        }
    }

    var localizedDescription: String {
        "\(number: self.scale, as: "0.#") x \(number: Rig.gtx1080ti.attempts_per_second(for: .bcrypt10), .abbreviated)/s " +
            "(~ \(number: self.fixed_budget, locale: .C, .currency, .abbreviated) + \(number: self.monthly_budget, .currency, .abbreviated)/m)"
    }

    var rig:                  Rig {
        .gtx1080ti
    }

    var fixed_budget:         Decimal {
        switch self {
            case .single: self.rig.cost_fixed
            case .private: 5000
            case .corporate: 20_000_000
            case .state: 5_000_000_000.0
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
        guard type.in(class: .template)
        else { return nil }

        var count     = 0
        let templates = UnsafeBufferPointer(start: spectre_type_templates(type, &count), count: count)
        defer { templates.deallocate() }

        var typePermutations: Decimal = .zero
        for template in templates {
            guard let template
            else { continue }

            var templatePermutations: Decimal = 1
            for c in .zero ..< strlen(template) {
                templatePermutations *= Decimal(strlen(spectre_class_characters(template[c])))
            }

            typePermutations += templatePermutations
        }

        return typePermutations
    }

    static func entropy(type: SpectreResultType) -> Int? {
        guard let permutations = self.permutations(type: type)
        else { return nil }

        return self.entropy(permutations: permutations)
    }

    func timeToCrack(type: SpectreResultType, hash: Hash = .bcrypt10) -> TimeToCrack? {
        guard let permutations = Self.permutations(type: type)
        else { return nil }

        return self.timeToCrack(permutations: permutations, hash: hash)
    }

    static func permutations(string: String?) -> Decimal? {
        guard var string, let vocabulary = Resources.shared.vocabulary
        else { return nil }

        var stringPermutations: Decimal = 1

        for word in vocabulary {
            let newString = string.replacingOccurrences(of: word, with: "")
            if newString != string {
                stringPermutations *= Decimal(vocabulary.count)
                string = newString
            }
        }

        var previousCharacter: Int32 = 0
        for passwordCharacter in string.utf8CString.map(Int32.init) {
            defer {
                previousCharacter = passwordCharacter
            }

            // Skip terminator and repeating characters.
            if passwordCharacter == 0 || abs(passwordCharacter - previousCharacter) < 2 {
                continue
            }

            var characterEntropy: Decimal = 256 /* a byte */
            for characterClass in ["v", "c", "a", "n", "x"] {
                guard let charactersForClass = spectre_class_characters(characterClass.utf8CString[0])
                else { continue }

                if strchr(charactersForClass, passwordCharacter) != nil {
                    // Found class for password character.
                    characterEntropy = Decimal(strlen(charactersForClass))
                    break
                }
            }

            stringPermutations *= characterEntropy
        }

        return stringPermutations
    }

    static func entropy(string: String?) -> Int? {
        guard let permutations = self.permutations(string: string)
        else { return nil }

        return self.entropy(permutations: permutations)
    }

    func timeToCrack(string: String?, hash: Hash = .bcrypt10) -> TimeToCrack? {
        guard let permutations = Self.permutations(string: string)
        else { return nil }

        return self.timeToCrack(permutations: permutations, hash: hash)
    }

    static func entropy(permutations: Decimal) -> Int {
        Int(truncating: permutations.log(base: 2).rounded(0, .down) as NSNumber)
    }

    func timeToCrack(permutations: Decimal, hash: Hash = .bcrypt10) -> TimeToCrack {
        // Amount of seconds to search half the permutations (average hit chance)
        var secondsToCrack = (permutations / 2) / self.rig.attempts_per_second(for: hash)

        // The search scale employed by the attacker.
        secondsToCrack /= self.scale

        // Convert seconds into other time scales.
        return TimeToCrack(permutations: permutations, attacker: self, period: .seconds(secondsToCrack))
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
