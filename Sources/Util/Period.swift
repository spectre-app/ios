//
// Created by Maarten Billemont on 2020-08-18.
// Copyright (c) 2020 Lyndir. All rights reserved.
//

import Foundation

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

    var localizedDescription: String {
        switch self {
            case .zero:
                return "now"
            case .universes:
                return "> age of the universe"
            case .seconds(let seconds):
                return seconds.isNaN ? "second": seconds == 1 ? "1 second": "\(seconds, numeric: "#,##0.#") seconds"
            case .hours(let hours):
                return hours.isNaN ? "hour": hours == 1 ? "1 hour": "\(hours, numeric: "#,##0.#") hours"
            case .days(let days):
                return days.isNaN ? "day": days == 1 ? "1 day": "\(days, numeric: "#,##0.#") days"
            case .weeks(let weeks):
                return weeks.isNaN ? "week": weeks == 1 ? "1 week": "\(weeks, numeric: "#,##0.#") weeks"
            case .months(let months):
                return months.isNaN ? "month": months == 1 ? "1 month": "\(months, numeric: "#,##0.#") months"
            case .years(let years):
                return years.isNaN ? "year": years == 1 ? "1 year": "\(years, numeric: "#,##0.#") years"
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
                return universes * 14_000_000_000.0 * 356 * 24 * 3600
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
