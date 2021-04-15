//
// Created by Maarten Billemont on 2020-08-18.
// Copyright (c) 2020 Lyndir. All rights reserved.
//

import Foundation

var age_of_the_universe : Decimal = 14_000_000_000.0 * 356 * 24 * 3600

enum Period {
    case hours(_ hours: Decimal), seconds(_ seconds: Decimal), zero
    case years(_ years: Decimal), months(_ months: Decimal), weeks(_ weeks: Decimal), days(_ days: Decimal)
    case universes(_ universes: Decimal)

    var amount: Decimal {
        switch self {
            case .zero:
                return 0
            case .seconds(let seconds):
                return seconds
            case .hours(let hours):
                return hours
            case .days(let days):
                return days
            case .weeks(let weeks):
                return weeks
            case .months(let months):
                return months
            case .years(let years):
                return years
            case .universes(let universes):
                return universes
        }
    }

    var brief: String {
        switch self {
            case .zero:
                return "Immediate"
            case .universes:
                return "Age of the universe"
            case .seconds(let seconds):
                return self.count( seconds, suffix: "Seconds" )
            case .hours(let hours):
                return self.count( hours, suffix: "Hours" )
            case .days(let days):
                return self.count( days, suffix: "Days" )
            case .weeks(let weeks):
                return self.count( weeks, suffix: "Weeks" )
            case .months(let months):
                return self.count( months, suffix: "Months" )
            case .years(let years):
                return self.count( years, suffix: "Years" )
        }
    }

    private func count(_ value: Decimal, suffix: String) -> String {
        if value > 1_000_000_000_000 {
            return "Trillions of \(suffix)"
        }
        else if value > 1_000_000_000 {
            return "Billions of \(suffix)"
        }
        else if value > 1_000_000 {
            return "Millions of \(suffix)"
        }
        else if value > 1_000 {
            return "Thousands of \(suffix)"
        }
        else if value > 100 {
            return "Hundreds of \(suffix)"
        }
        else {
            return suffix
        }
    }

    var localizedDescription: String {
        switch self {
            case .zero:
                return "now"
            case .universes:
                return "> age of the universe"
            case .seconds(let seconds):
                return seconds.isNaN ? "unknown": seconds == 1 ? "1 second": "\(number: seconds, decimals: 0...1, .abbreviated) seconds"
            case .hours(let hours):
                return hours.isNaN ? "unknown": hours == 1 ? "1 hour": "\(number: hours, decimals: 0...1, .abbreviated) hours"
            case .days(let days):
                return days.isNaN ? "unknown": days == 1 ? "1 day": "\(number: days, decimals: 0...1, .abbreviated) days"
            case .weeks(let weeks):
                return weeks.isNaN ? "unknown": weeks == 1 ? "1 week": "\(number: weeks, decimals: 0...1, .abbreviated) weeks"
            case .months(let months):
                return months.isNaN ? "unknown": months == 1 ? "1 month": "\(number: months, decimals: 0...1, .abbreviated) months"
            case .years(let years):
                return years.isNaN ? "unknown": years == 1 ? "1 year": "\(number: years, decimals: 0...1, .abbreviated) years"
        }
    }

    var seconds: Decimal {
        switch self {
            case .zero:
                return 0
            case .seconds(let seconds):
                return seconds
            case .hours(let hours):
                return hours * 3600
            case .days(let days):
                return days * 24 * 3600
            case .weeks(let weeks):
                return weeks * 7 * 24 * 3600
            case .months(let months):
                return months * 30 * 24 * 3600
            case .years(let years):
                return years * 356 * 24 * 3600
            case .universes(let universes):
                return universes * age_of_the_universe
        }
    }

    var normalize: Period {
        let seconds = self.seconds
        if seconds == 0 {
            return .zero
        }

        let hours = seconds / 3600
        if hours <= 1 {
            return .seconds( seconds )
        }

        let days = hours / 24
        if days <= 1 {
            return .hours( hours )
        }

        let weeks = days / 7
        if weeks <= 1 {
            return .days( days )
        }

        let months = days / 30
        if months <= 1 {
            return .weeks( weeks )
        }

        let years = days / 356
        if years <= 1 {
            return .months( months )
        }

        let universes = years / 14_000_000_000.0
        if universes <= 1 {
            return .years( years )
        }

        return .universes( universes )
    }
}
