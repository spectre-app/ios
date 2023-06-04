//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import Foundation

var age_of_the_universe: Decimal = 14_000_000_000.0 * 356 * 24 * 3600

enum Period {
    case hours(_ hours: Decimal), seconds(_ seconds: Decimal), zero
    case years(_ years: Decimal), months(_ months: Decimal), weeks(_ weeks: Decimal), days(_ days: Decimal)
    case universes(_ universes: Decimal)

    var amount: Decimal {
        switch self {
            case .zero: 0
            case let .seconds(seconds): seconds
            case let .hours(hours): hours
            case let .days(days): days
            case let .weeks(weeks): weeks
            case let .months(months): months
            case let .years(years): years
            case let .universes(universes): universes
        }
    }

    var brief: String {
        switch self {
            case .zero: "Immediate"
            case .universes: "Age of the universe"
            case let .seconds(seconds): self.count(seconds, suffix: "Seconds")
            case let .hours(hours): self.count(hours, suffix: "Hours")
            case let .days(days): self.count(days, suffix: "Days")
            case let .weeks(weeks): self.count(weeks, suffix: "Weeks")
            case let .months(months): self.count(months, suffix: "Months")
            case let .years(years): self.count(years, suffix: "Years")
        }
    }

    private func count(_ value: Decimal, suffix: String) -> String {
        if value > 1_000_000_000_000 {
            "Trillions of \(suffix)"
        }
        else if value > 1_000_000_000 {
            "Billions of \(suffix)"
        }
        else if value > 1_000_000 {
            "Millions of \(suffix)"
        }
        else if value > 1000 {
            "Thousands of \(suffix)"
        }
        else if value > 100 {
            "Hundreds of \(suffix)"
        }
        else {
            suffix
        }
    }

    var localizedDescription: String {
        switch self {
            case .zero: "now"
            case .universes: "> age of the universe"
            case let .seconds(seconds):
                seconds.isNaN ? "second" : seconds == 1 ? "1 second" : "\(number: seconds, decimals: 0 ... 1, .abbreviated) seconds"
            case let .hours(hours):
                hours.isNaN ? "hour" : hours == 1 ? "1 hour" : "\(number: hours, decimals: 0 ... 1, .abbreviated) hours"
            case let .days(days):
                days.isNaN ? "day" : days == 1 ? "1 day" : "\(number: days, decimals: 0 ... 1, .abbreviated) days"
            case let .weeks(weeks):
                weeks.isNaN ? "week" : weeks == 1 ? "1 week" : "\(number: weeks, decimals: 0 ... 1, .abbreviated) weeks"
            case let .months(months):
                months.isNaN ? "month" : months == 1 ? "1 month" : "\(number: months, decimals: 0 ... 1, .abbreviated) months"
            case let .years(years):
                years.isNaN ? "year" : years == 1 ? "1 year" : "\(number: years, decimals: 0 ... 1, .abbreviated) years"
        }
    }

    var seconds: Decimal {
        switch self {
            case .zero: 0
            case let .seconds(seconds): seconds
            case let .hours(hours): hours * 3600
            case let .days(days): days * 24 * 3600
            case let .weeks(weeks): weeks * 7 * 24 * 3600
            case let .months(months): months * 30 * 24 * 3600
            case let .years(years): years * 356 * 24 * 3600
            case let .universes(universes): universes * age_of_the_universe
        }
    }

    var normalize: Period {
        let seconds = self.seconds
        if seconds == .zero {
            return .zero
        }

        let hours = seconds / 3600
        if hours <= 1 {
            return .seconds(seconds)
        }

        let days = hours / 24
        if days <= 1 {
            return .hours(hours)
        }

        let weeks = days / 7
        if weeks <= 1 {
            return .days(days)
        }

        let months = days / 30
        if months <= 1 {
            return .weeks(weeks)
        }

        let years = days / 356
        if years <= 1 {
            return .months(months)
        }

        let universes = years / 14_000_000_000.0
        if universes <= 1 {
            return .years(years)
        }

        return .universes(universes)
    }
}
