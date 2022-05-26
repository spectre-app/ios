// =============================================================================
// Created by Maarten Billemont on 2020-09-11.
// Copyright (c) 2020 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import Foundation

extension Array {
    subscript(maybe index: Index) -> Element? {
        index < self.underestimatedCount || index < self.count ? self[index] : nil
    }

    func reordered(first: ((Element) -> Bool)? = nil, last: ((Element) -> Bool)? = nil) -> [Element] {
        var firstElements = [ Element ](), middleElements = [ Element ](), lastElements = [ Element ]()

        for element in self {
            if first?( element ) ?? false {
                firstElements.append( element )
            }
            else if last?( element ) ?? false {
                lastElements.append( element )
            }
            else {
                middleElements.append( element )
            }
        }

        return firstElements + middleElements + lastElements
    }
}

extension Collection {
    func joinedIntersection<C>(_ other: C) -> [(Element, Element)]
            where Element: Equatable, Element == C.Element, C: Collection {
        (self.count < other.count) ? self.compactMap { lhs in
            guard let rhs = other.first( where: { rhs in lhs == rhs } )
            else { return nil }
            return (lhs, rhs)
        } : other.compactMap { rhs in
            guard let lhs = self.first( where: { lhs in lhs == rhs } )
            else { return nil }
            return (lhs, rhs)
        }
    }
}

extension Collection where Element == UInt8 {
    func hex() -> String {
        let hex = NSMutableString( capacity: self.count * 2 )
        self.forEach { hex.appendFormat( "%02hhX", $0 ) }

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

            // For some reason, underflow never triggers an error on NSDecimalMultiply,
            // so you need to check for when values get too small and abort convergence manually at that point
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

    mutating func round(_ scale: Int, _ roundingMode: NSDecimalNumber.RoundingMode) {
        var _self = self
        NSDecimalRound( &self, &_self, scale, roundingMode )
    }

    func rounded(_ scale: Int, _ roundingMode: NSDecimalNumber.RoundingMode) -> Decimal {
        var _self = self, result = Decimal()
        NSDecimalRound( &result, &_self, scale, roundingMode )
        return result
    }
}

extension Dictionary {
    init<S: Sequence>(enumerated: S) where Key == Int, S.Element == Value {
        self.init( uniqueKeysWithValues: enumerated.enumerated().map { ($0.offset, $0.element) } )
    }

    subscript(key: Key, defaultSet defaultValue: @autoclosure () -> Value) -> Value {
        mutating get {
            if let value = self[key] {
                return value
            }

            let value = defaultValue()
            self[key] = value
            return value
        }
        mutating set {
            self[key] = newValue
        }
    }
}

extension FileManager {
    public static let groupCaches    = FileManager.default.containerURL( forSecurityApplicationGroupIdentifier: productGroup )?
                                                  .appendingPathComponent( "Library/Caches" )
    public static let groupDocuments = FileManager.default.containerURL( forSecurityApplicationGroupIdentifier: productGroup )?
                                                  .appendingPathComponent( "Documents" )
    public static let appDocuments   = FileManager.default.urls( for: .documentDirectory, in: .userDomainMask ).first
}

extension Locale {
    public static let C = Locale( identifier: "en_US_POSIX" )
}

extension NSAttributedString {
    public static func + (lhs: NSAttributedString, rhs: NSAttributedString) -> NSAttributedString {
        let attributedString = lhs as? NSMutableAttributedString ?? NSMutableAttributedString( attributedString: lhs )
        attributedString.append( rhs )
        return attributedString
    }

    public convenience init(string: String, font: UIFont? = nil, textColor: UIColor? = nil, secondaryColor: UIColor? = nil,
                            _ attributes: [NSAttributedString.Key: Any] = [:]) {
        self.init( attributedString: NSMutableAttributedString( string: string ),
                   textColor: textColor, secondaryColor: secondaryColor, attributes )
    }

    public convenience init(attributedString: NSAttributedString, font: UIFont? = nil, textColor: UIColor? = nil, secondaryColor: UIColor? = nil,
                            _ attributes: [NSAttributedString.Key: Any] = [:]) {
        self.init( attributedString: NSMutableAttributedString( attributedString: attributedString ),
                   textColor: textColor, secondaryColor: secondaryColor, attributes )
    }

    public convenience init(attributedString: NSMutableAttributedString, font: UIFont? = nil, textColor: UIColor? = nil, secondaryColor: UIColor? = nil,
                            _ attributes: [NSAttributedString.Key: Any] = [:]) {
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

        attributedString.setAttributes( attributes, range: NSRange( location: 0, length: attributedString.length ) )
        self.init( attributedString: attributedString )
    }

    func attributeLocations(_ attrName: NSAttributedString.Key, in range: NSRange? = nil, options: EnumerationOptions = []) -> [Int] {
        var locations = [ Int ]()
        self.enumerateAttribute( attrName, in: range ?? NSRange( location: 0, length: self.length ), options: options ) { value, range, _ in
            if value != nil {
                locations.append( range.location )
            }
        }
        return locations
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
    public static let immediate: TimeInterval = .off

    public static func seconds(_ seconds: Double) -> TimeInterval {
        TimeInterval( seconds )
    }

    public static func milliseconds(_ milliseconds: Double) -> TimeInterval {
        .seconds( milliseconds / 1000 )
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

extension URLComponents {
    public func verifySignature() -> Bool {
        guard let signature = self.queryItems?.first( where: { $0.name == "signature" } )?.value as String?
        else { return false }

        guard let url = self.url, var components = URLComponents( url: url, resolvingAgainstBaseURL: false )
        else { return false }

        components.queryItems = components.queryItems?.filter( { $0.name != "signature" } ).nonEmpty
        guard let unsignedString = components.url?.absoluteString
        else { return false }

        return signature == unsignedString.digest()?.base64EncodedString()
    }
}

extension URLRequest {
    init(method: Method, url: URL) {
        self.init( url: url )

        self.httpMethod = method.description
    }

    enum Method: CustomStringConvertible {
        case get, head, post, put, delete, connect, options, trace, patch

        var description: String {
            switch self {
                case .get:
                    return "get"
                case .head:
                    return "head"
                case .post:
                    return "post"
                case .put:
                    return "put"
                case .delete:
                    return "delete"
                case .connect:
                    return "connect"
                case .options:
                    return "options"
                case .trace:
                    return "trace"
                case .patch:
                    return "patch"
            }
        }
    }
}

private let requiredQueue = DispatchQueue( label: "\(productName): Network Required", qos: .userInitiated, attributes: [ .concurrent ] )
private let optionalQueue = DispatchQueue( label: "\(productName): Network Optional", qos: .background, attributes: [ .concurrent ] )

extension URLSession {
    public static var required = LazyBox<URLSession> {
        guard AppConfig.shared.isEnabled, !AppConfig.shared.offline
        else { return nil }

        return URLSession( configuration: requiredConfiguration(), delegate: nil, delegateQueue: OperationQueue( queue: requiredQueue ) )
    } unset: {
        $0.invalidateAndCancel()
    }
    public static var optional = LazyBox<URLSession> {
        guard AppConfig.shared.isEnabled, !AppConfig.shared.offline
        else { return nil }

        return URLSession( configuration: optionalConfiguration(), delegate: nil, delegateQueue: OperationQueue( queue: optionalQueue ) )
    } unset: {
        $0.invalidateAndCancel()
    }

    public static func requiredConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpCookieStorage = nil
        configuration.httpAdditionalHeaders = [
            "User-Agent": "\(productName)/\(productVersion) " +
                          "(\(UIDevice.current.model); CPU \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)) " +
                          "Mozilla/5.0 AppleWebKit/605.1.15",
        ]
        configuration.sharedContainerIdentifier = productGroup
        configuration.networkServiceType = .responsiveData
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        return configuration
    }

    public static func optionalConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpCookieStorage = nil
        configuration.httpAdditionalHeaders = [
            "User-Agent": "\(productName)/\(productVersion) " +
                          "(\(UIDevice.current.model); CPU \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)) " +
                          "Mozilla/5.0 AppleWebKit/605.1.15",
        ]
        configuration.sharedContainerIdentifier = productGroup
        configuration.networkServiceType = .background
        configuration.timeoutIntervalForResource = TimeInterval( 600 /* 10 min */ )
        configuration.isDiscretionary = true
        configuration.waitsForConnectivity = true
        configuration.allowsExpensiveNetworkAccess = false
        configuration.allowsConstrainedNetworkAccess = false
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        return configuration
    }

    public func promise(with request: URLRequest) -> Promise<(data: Data, response: URLResponse)> {
        let promise = Promise<(data: Data, response: URLResponse)>()
        self.dataTask( with: request ) {
                if let error = $2 {
                    promise.finish( .failure( error ) )
                }
                else if let data = $0, let response = $1 {
                    promise.finish( .success( (data, response) ) )
                }
                else {
                    promise.finish( .failure( AppError.internal( cause: "Missing error, data or response to URL request", details: request ) ) )
                }
            }
            .resume()
        return promise
    }
}
