//
// Created by Maarten Billemont on 2020-09-11.
// Copyright (c) 2020 Lyndir. All rights reserved.
//

import Foundation

extension Data {
    func hex() -> String {
        let hex = NSMutableString( capacity: self.count * 2 )
        self.forEach { hex.appendFormat( "%02.2hhX", $0 ) }

        return hex as String
    }
}

extension Date {
    func format(date dateStyle: DateFormatter.Style = .medium, time timeStyle: DateFormatter.Style = .medium)
                    -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = dateStyle
        dateFormatter.timeStyle = timeStyle
        return dateFormatter.string( from: self )
    }
}

extension Decimal {
    static let e = Decimal( string: "2.7182818284590452353602874713526624977572470936999595749669676277240766303535475945713821785251664" )!

    func log(base: Decimal) -> Decimal {
        self.ln() / base.ln()
    }

    func ln() -> Decimal {
        // https://en.wikipedia.org/wiki/Logarithm#Power_series -- "More efficient series"

        // To speed convergence, using ln(z) = y + ln(A), A = z / e^y approximation for values larger than 1.5
        let approximateInput = Double( truncating: self as NSNumber )
        if approximateInput > 1.5 {
            let y       = Int( ceil( Darwin.log( approximateInput ) ) )
            // Using integer because of more precise powers for integers
            let smaller = self / pow( Decimal.e, y )
            return Decimal( y ) + smaller.ln()
        }
        if approximateInput < 0.4 {
            let y       = Int( floor( Darwin.log( approximateInput ) ) )
            // Using integer because of more precise powers for integers
            let smaller = self / pow( Decimal.e, y )
            return Decimal( y ) + smaller.ln()
        }

        let seriesConstant       = (self - 1) / (self + 1)
        var currentConstantValue = seriesConstant, final = seriesConstant
        for i in stride( from: 3, through: 93, by: 2 ) {
            currentConstantValue *= seriesConstant

            // For some reason, underflow never triggers an error on NSDecimalMultiply, so you need to check for when values get too small and abort convergence manually at that point
            var rounded: Decimal = 0
            NSDecimalRound( &rounded, &currentConstantValue, 80, .bankers )
            if rounded == 0 {
                break
            }

            currentConstantValue *= seriesConstant
            NSDecimalRound( &rounded, &currentConstantValue, 80, .bankers )
            if rounded == 0 {
                break
            }

            var currentFactor = currentConstantValue / Decimal( i )
            NSDecimalRound( &rounded, &currentFactor, 80, .bankers )
            if rounded == 0 {
                break
            }

            final += currentFactor
        }

        return 2 * final
    }
}

extension Locale {
    public static let C = Locale( identifier: "en_US_POSIX" )
}

extension NSAttributedString {
    public static func +(lhs: NSAttributedString, rhs: NSAttributedString) -> NSAttributedString {
        let attributedString = lhs as? NSMutableAttributedString ?? NSMutableAttributedString( attributedString: lhs )
        attributedString.append( rhs )
        return attributedString
    }

    public static func str(_ string: String, font: UIFont? = nil, textColor: UIColor? = nil, secondaryColor: UIColor? = nil,
                           _ attributes: [NSAttributedString.Key: Any] = [:]) -> NSAttributedString {
        var mergedAttributes = attributes
        if let font = font {
            mergedAttributes[.font] = font
        }
        if let textColor = textColor {
            mergedAttributes[.foregroundColor] = textColor
        }
        if let secondaryColor = secondaryColor {
            mergedAttributes[.strokeColor] = secondaryColor
        }

        return NSAttributedString( string: string, attributes: mergedAttributes )
    }
}

extension NSOrderedSet {
    func seq<E>(_ type: E.Type) -> [E] {
        self.array as! [E]
    }
}

extension OperationQueue {
    convenience init(named name: String) {
        self.init()

        self.name = name
    }

    convenience init(queue: DispatchQueue) {
        self.init()

        self.name = queue.label
        self.underlyingQueue = queue
    }
}

extension TimeInterval {
    public static func seconds(_ seconds: Double) -> TimeInterval {
        TimeInterval( seconds )
    }

    public static func minutes(_ minutes: Double) -> TimeInterval {
        .seconds( minutes * 60 )
    }

    public static func hours(_ hours: Double) -> TimeInterval {
        .minutes( hours * 60 )
    }

    public static func days(_ days: Double) -> TimeInterval {
        .hours( days * 24 )
    }
}

extension UserDefaults {
    public static let shared = UserDefaults( suiteName: productGroup ) ?? UserDefaults.standard
}
