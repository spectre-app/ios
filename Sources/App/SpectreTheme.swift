//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import AuthenticationServices
import SwiftUI
import WrappingHStack
@_spi(Advanced) import SwiftUIIntrospect

/// - Fonts and Colors

extension CGFloat {
    public static let spectre = Spectre()

    public struct Spectre {
        public let padding: CGFloat = 8
        public let spacer: CGFloat = 12
        public let margin: CGFloat = 20
        public let control: CGFloat = 40
        public let shape: CGFloat = 128
    }
}

extension Font {
    public static let spectre = SpectreFont()

    public struct SpectreFont {
        public let largeTitle = Font.custom("Poppins", relativeTo: .largeTitle).weight(.black)
        public let title1 = Font.custom("Poppins", relativeTo: .title).weight(.regular)
        public let title2 = Font.custom("Poppins", relativeTo: .title2).weight(.medium)
        public let title3 = Font.custom("Poppins", relativeTo: .title3).weight(.regular)
        public let headline = Font.custom("Poppins", relativeTo: .headline).weight(.semibold)
        public let subheadline = Font.custom("Poppins", relativeTo: .subheadline).weight(.medium)
        public let body = Font.custom("Poppins", relativeTo: .body).weight(.light)
        public let callout = Font.custom("Poppins", relativeTo: .callout).weight(.regular)
        public let caption1 = Font.custom("Poppins", relativeTo: .caption).weight(.regular)
        public let caption2 = Font.custom("Poppins", relativeTo: .caption2).weight(.medium)
        public let footnote = Font.custom("Poppins", relativeTo: .footnote).weight(.medium)
        public let password = Font.custom("Source Code Pro", relativeTo: .largeTitle)
        public let mono = Font.custom("Source Code Pro", relativeTo: .body).monospacedDigit().weight(.thin)
    }
}

extension Color {
    public static let spectre = Spectre()

    public struct Spectre {
        public let body = Color(Style(light: \.dark, dark: \.pale))
        public let selection = Color(Style(light: \.dark, dark: \.pale, opacity: .short))
        public let shadow = Color(Style(light: \.dark, dark: \.pale, opacity: .short * .short))
        public let tint = Color(Style(light: \.dusk, dark: \.dawn))
        public let alternative = Color(Style(light: \.dusk, dark: \.dawn, opacity: .long))
        public let placeholder = Color(Style(light: \.dusk, dark: \.dawn, opacity: .short * .short))
        public let mute = Color(Style(light: \.dusk, dark: \.dawn, opacity: .short * .short * .short))
        public let backdrop = Color(Style(light: \.pale, dark: \.dark))
        public let panel = Color(Style(light: \.dawn, dark: \.dusk))
        public let shade = Color(Style(light: \.dawn, dark: \.dusk, opacity: .long))

        public struct Style: Hashable, ShapeStyle {
            public let light: KeyPath<Theme, Color.Resolved?>
            public let dark: KeyPath<Theme, Color.Resolved?>
            public var opacity: Float = 1

            public func resolve(in environment: EnvironmentValues) -> Color.Resolved {
                using({
                    switch environment.colorScheme {
                        case .dark:
                            environment.theme[keyPath: self.dark]

                        default:
                            environment.theme[keyPath: self.light]
                    }
                }() ?? .init(red: .on, green: .off, blue: .off)) {
                    $0.opacity *= self.opacity
                }
            }
        }

        public struct Theme: Hashable, Sendable, CaseIterable {
            public static let allCases = [spectre, dream, deep, sand, lush, oak, spring, fuzzy, premium, pale, aged]
            public static let spectre = Self(
                rawValue: ".spectre",
                dark: .init(hex: "0E3345"),
                dusk: .init(hex: "173D50"),
                flat: .init(hex: "41A0A0"),
                dawn: .init(hex: "F1F9FC"),
                pale: .init(hex: "FFFFFF"),
                mood: "It's just a mental reflection."
            )
            public static let dream   = Self(
                rawValue: ".dream",
                dark: .init(hex: "385359"),
                dusk: .init(hex: "4C6C73"),
                flat: .init(hex: "64858C"),
                dawn: .init(hex: "AAB9BF"),
                pale: .init(hex: "F2F2F2"),
                mood: "This weather is for dreaming."
            )
            public static let deep    = Self(
                rawValue: ".deep",
                dark: .init(hex: "1A2A40"),
                dusk: .init(hex: "3F4859"),
                flat: .init(hex: "877B8C"),
                dawn: .init(hex: "B6A8BF"),
                pale: .init(hex: "BFCDD9"),
                mood: "I am my past and I am beautiful."
            )
            public static let sand    = Self(
                rawValue: ".sand",
                dark: .init(hex: "0D0D0D"),
                dusk: .init(hex: "736656"),
                flat: .init(hex: "A69880"),
                dawn: .init(hex: "D9CDBF"),
                pale: .init(hex: "F2EEEB"),
                mood: "Sandstone cabin by the beech."
            )
            public static let lush    = Self(
                rawValue: ".lush",
                dark: .init(hex: "141F26"),
                dusk: .init(hex: "213A40"),
                flat: .init(hex: "4C6C73"),
                dawn: .init(hex: "5D878C"),
                pale: .init(hex: "F0F1F2"),
                mood: "A clean and modest kind of lush."
            )
            public static let oak     = Self(
                rawValue: ".oak",
                dark: .init(hex: "0D0D0D"),
                dusk: .init(hex: "262523"),
                flat: .init(hex: "595958"),
                dawn: .init(hex: "A68877"),
                pale: .init(hex: "D9C9BA"),
                mood: "The cabin below deck on my yacht."
            )
            public static let spring  = Self(
                rawValue: ".spring",
                dark: .init(hex: "0D0D0D"),
                dusk: .init(hex: "2E5955"),
                flat: .init(hex: "618C8C"),
                dawn: .init(hex: "99BFBF"),
                pale: .init(hex: "F2F2F2"),
                mood: "Bright morning fog in spring-time."
            )
            public static let fuzzy   = Self(
                rawValue: ".fuzzy",
                dark: .init(hex: "000F08"),
                dusk: .init(hex: "004A4F"),
                flat: .init(hex: "3E8989"),
                dawn: .init(hex: "9AD5CA"),
                pale: .init(hex: "CCE3DE"),
                mood: "Soft and just a touch fuzzy."
            )
            public static let premium = Self(
                rawValue: ".premium",
                dark: .init(hex: "0D0D0D"),
                dusk: .init(hex: "313A40"),
                flat: .init(hex: "593825"),
                dawn: .init(hex: "BFB7A8"),
                pale: .init(hex: "F2D5BB"),
                mood: "The kind of wealthy you don't advertise."
            )
            public static let pale    = Self(
                rawValue: ".pale",
                dark: .init(hex: "09090D"),
                dusk: .init(hex: "1F1E26"),
                flat: .init(hex: "3E5159"),
                dawn: .init(hex: "5E848C"),
                pale: .init(hex: "B0CDD9"),
                mood: "Weathered stone foundation standing tall."
            )
            public static let aged    = Self(
                rawValue: ".aged",
                dark: .init(hex: "07090D"),
                dusk: .init(hex: "1E2626"),
                flat: .init(hex: "6C7365"),
                dawn: .init(hex: "A3A68D"),
                pale: .init(hex: "BBBF9F"),
                mood: "Whiff of a Victorian manuscript."
            )

            public let rawValue: String
            public let dark: Color.Resolved?
            public let dusk: Color.Resolved?
            public let flat: Color.Resolved?
            public let dawn: Color.Resolved?
            public let pale: Color.Resolved?
            public let mood: String

            public var isPremium: Bool {
                self != .spectre
            }
        }
    }
}

/// A shape that is a rectangle no smaller than the control size.
public struct ControlShape: Shape {
    public func path(in rect: CGRect) -> Path {
        Path {
            $0.addRect(CGRect(
                x: min(rect.minX, rect.midX - .spectre.control / 2),
                y: min(rect.minY, rect.midY - .spectre.control / 2),
                width: max(rect.width, .spectre.control),
                height: max(rect.height, .spectre.control)
            ))
        }
    }
}

extension Color.Spectre.Theme: RawRepresentable, Identifiable {
    public init?(rawValue: String) {
        guard let theme = Self.allCases.first(where: { $0.rawValue == rawValue })
        else { return nil }

        self = theme
    }
}

extension Gradient {
    public static func stripes(count: Int = 2, tint: Color = .spectre.tint,
                               opacity1: CGFloat = .long, opacity2: CGFloat = .short)
        -> Self {
        self.stripes(count: count, color1: tint.opacity(opacity1), color2: tint.opacity(opacity2))
    }

    public static func stripes(count: Int = 2, color1: Color, color2: Color)
        -> Self {
        Gradient(stops: stride(from: .zero, to: count, by: 2).flatMap { (step: Int) in
            [
                Gradient.Stop(color: color1, location: CGFloat(step) / CGFloat(count)),
                Gradient.Stop(color: color2, location: CGFloat(step) / CGFloat(count)),
                Gradient.Stop(color: color2, location: CGFloat(step + 1) / CGFloat(count)),
                Gradient.Stop(color: color1, location: CGFloat(step + 1) / CGFloat(count)),
            ]
        })
    }
}

extension LinearGradient {
    public static func angled(gradient: Gradient = .stripes(), angle: Angle = .degrees(20)) -> Self {
        Self(
            gradient: gradient, startPoint: .zero,
            endPoint: .init(x: cos(CGFloat(angle.radians)), y: sin(CGFloat(angle.radians)))
        )
    }

    public static func fade(axis: Axis, colors: [Color] = [.clear, .black]) -> Self {
        switch axis {
            case .horizontal: LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
            case .vertical: LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
        }
    }

    public static func fade(from: UnitPoint, to: UnitPoint, colors: [Color] = [.clear, .black]) -> Self {
        LinearGradient(colors: colors, startPoint: from, endPoint: to)
    }
}

public struct GradientView: View {
    public var width: CGFloat = .spectre.shape / 2
    public var angle: Angle = .degrees(20)
    public var gradient: Gradient = .stripes()

    @State
    private var offset: CGPoint = .zero
    @State
    private var view: UIView?

    public var body: some View {
        let radius = self.width * 2, radians = CGFloat(self.angle.radians)

        Canvas {
            $0.fill(
                Path(CGRect(origin: .zero, size: $1)),
                with: .linearGradient(
                    self.gradient, startPoint: self.offset, endPoint: .init(
                        x: radius * cos(radians), y: radius * sin(radians)
                    ) + self.offset, options: .repeat
                )
            )
        }
        .introspect(.view, on: .iOS(.v18...)) { view in
            DispatchQueue.main.async {
                self.view = view
            }
        }
        .onGeometryChange(for: CGPoint.self) { $0.frame(in: .global).origin } action: {
            var scrollOffset = CGPoint.zero, view: UIView? = self.view
            while let superView = view?.superview {
                if let scrollView = superView as? UIScrollView {
                    scrollOffset += scrollView.contentOffset
                }
                view = superView
            }
            self.offset = -$0 - scrollOffset
        }
    }
}

/// - App

@Observable
final class SpectreModel: UserObserver {
    static var shared = SpectreModel()
    private init() {}

    var activeUser: User? {
        willSet {
            if let activeUser, newValue != activeUser {
                activeUser.observers.unregister(observer: self)
            }
        }
        didSet {
            if let activeUser, oldValue != activeUser {
                activeUser.observers.register(observer: self)
            }
        }
    }

    var isReportingMemory = false
    var autofill: AutoFill?

    @discardableResult
    func loginExistingUser(_ existingUser: Marshal.UserFile, using keyFactory: KeyFactory) async throws -> User {
        let user = try await existingUser.authenticate(using: keyFactory)
        self.activeUser = user
        return user
    }

    @discardableResult
    func loginNewUser(using keyFactory: KeyFactory) async throws -> User {
        let user = try await User(userName: keyFactory.userName).login(using: keyFactory)
        self.activeUser = user
        return user
    }

    @discardableResult
    func loginIncognitoUser(using keyFactory: KeyFactory) async throws -> User {
        let user = try await User(userName: keyFactory.userName, file: nil).login(using: keyFactory)
        self.activeUser = user
        return user
    }

    func reportMemory() {
        self.isReportingMemory = true
    }

    // - UserObserver

    func didLogout(user: User) {
        if self.activeUser == user {
            self.activeUser = nil
        }
    }

    struct AutoFill {
        var extensionContext: ASCredentialProviderExtensionContext?
        var serviceIdentifiers: [ASCredentialServiceIdentifier]?
        var credentialRequest: ASCredentialRequest?
        var isRequestingCredentials: Bool {
            self.credentialRequest != nil || self.serviceIdentifiers != nil
        }

        func complete(with credential: ASPasswordCredential) async -> Bool {
            await withCheckedContinuation { continuation in
                self.extensionContext?.completeRequest(withSelectedCredential: credential) { expired in
                    continuation.resume(returning: !expired)
                } ?? continuation.resume(returning: false)
            }
        }

        func cancel(with error: ASExtensionError) {
            self.extensionContext?.cancelRequest(withError: error)
        }
    }
}

extension EnvironmentValues {
    var spectre: SpectreModel {
        get { self[SpectreModelKey.self] }
        set { self[SpectreModelKey.self] = newValue }
    }

    var config: AppConfig {
        get { self[SpectreConfigKey.self] }
        set { self[SpectreConfigKey.self] = newValue }
    }

    var containerSize: CGSize {
        get { self[ContainerSizeKey.self] }
        set { self[ContainerSizeKey.self] = newValue }
    }

    fileprivate var theme: Color.Spectre.Theme {
        get { self[SpectreThemeKey.self] }
        set { self[SpectreThemeKey.self] = newValue }
    }

    private struct SpectreThemeKey: EnvironmentKey {
        static let defaultValue: Color.Spectre.Theme = AppConfig.shared.theme
    }

    private struct SpectreModelKey: EnvironmentKey {
        static let defaultValue: SpectreModel = .shared
    }

    private struct SpectreConfigKey: EnvironmentKey {
        static let defaultValue: AppConfig = .shared
    }

    private struct ContainerSizeKey: EnvironmentKey {
        static let defaultValue: CGSize = .zero
    }
}

extension View {
    public func spectreStyle(background: some ShapeStyle = Gradient(colors: [.spectre.backdrop, .spectre.panel])) -> some View {
        self.modifier(SpectreStyle(background: AnyShapeStyle(background)))
    }
}

extension CoordinateSpaceProtocol where Self == NamedCoordinateSpace {
    public static var spectre: NamedCoordinateSpace { named("spectre") }
}

struct SpectreStyle: ViewModifier {
    public var background: AnyShapeStyle

    @Environment(\.spectre)
    private var spectre: SpectreModel
    @State
    private var config: AppConfig = .shared
    @State
    private var containerSize: CGSize = .zero

    func body(content: Content) -> some View {
        NavigationStack {
            content
                .containerBackground(BackgroundStyle(), for: .navigation)
        }
        .modifier(MessagesHost())

        // Style
        .tint(.spectre.tint)
        .presentationBackground(self.background)
        .backgroundStyle(self.background)
        .foregroundStyle(Color.spectre.body, Color.spectre.tint, Color.spectre.placeholder)
        .symbolRenderingMode(.hierarchical)
        .scrollContentBackground(.hidden)
        .labeledContentStyle(.spectreHorizontal)
        .buttonStyle(.spectre)
        .controlGroupStyle(.spectre)
        // .datePickerStyle(.spectre)
        .formStyle(.spectre)
        // .menuStyle(.spectre)
        // .pickerStyle(.spectre)
        .toggleStyle(.spectre)
        // .gaugeStyle(.spectre)
        // .progressViewStyle(.spectre)
        .labelStyle(.spectre)
        .listStyle(.plain)
        // .textFieldStyle(.spectre)
        // .textEditorStyle(.spectre)
        // .tableStyle(.spectre)
        // .disclosureGroupStyle(.spectre)
        // .navigationSplitViewStyle(.spectre)
        // .tabViewStyle(.spectre)
        .groupBoxStyle(.spectre)
        // .indexViewStyle(.spectre)
        .font(.spectre.body)
        .onGeometryChange(for: CGSize.self, of: \.size) { self.containerSize = $0 }

        // Environment
        .environment(\.containerSize, self.containerSize)
        .environment(\.theme, self.config.theme)
        .environmentObject(self.config)
        .defaultAppStorage(.shared)
    }
}

/// - Button

extension PrimitiveButtonStyle where Self == SpectreButtonStyle {
    public static var spectre: Self { Self() }

    public static func spectre(@ViewBuilder with accessory: @escaping () -> some View) -> Self {
        Self(accessory: { AnyView(accessory()) })
    }
}

public struct SpectreButtonStyle: PrimitiveButtonStyle {
    var accessory: (() -> AnyView)?

    @Environment(\.isEnabled)
    private var isEnabled
    @State
    private var isPressing = false
    @State
    private var isPressed = false

    public func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Path()
                .frame(width: .spectre.control, height: .spectre.control)
                .padding(-.spectre.padding)

            HStack(spacing: .spectre.padding) {
                configuration.label

                if let accessory {
                    Color.spectre.placeholder
                        .frame(width: 1, height: .spectre.control - .spectre.padding * 2)

                    accessory()
                }
            }
        }
        .padding(.spectre.padding)
        .font(.spectre.callout)
        .animation(.default) { $0
            .background {
                self.isEnabled ? Color.spectre.placeholder : .spectre.mute
            }
            .cornerRadius(.spectre.spacer)
            .overlay {
                RoundedRectangle(cornerRadius: .spectre.spacer)
                    .strokeBorder(Color.spectre.body)
                    .opacity(self.isPressed || self.isPressing ? .on : .off)
                    .paddingEffect(self.isPressed ? -.spectre.padding / 2 : .zero)
            }
        }
        .animation(.default.delay(self.isPressing ? .zero : .short)) { $0
            .paddingEffect(self.isPressing ? -.spectre.padding / 2 : .zero)
        }
        ._onButtonGesture(pressing: {
            self.isPressing = $0
        }, perform: {
            self.isPressing = false
            self.isPressed = true
            configuration.trigger()
            Task {
                try? await Task.sleep(for: .seconds(.short))
                self.isPressed = false
            }
        })
//        .strikethrough(!self.isEnabled)
        .opacity(self.isEnabled ? .on : .short)
        .saturation(self.isEnabled ? .on : .off)
    }
}

extension PrimitiveButtonStyle where Self == SpectreBoxButtonStyle {
    public static func spectreBox(alignment: Alignment = .topTrailing, systemImage: String?,
                                  @ViewBuilder with background: @escaping () -> some View = { EmptyView() })
        -> Self {
        self.spectreBox(alignment: alignment, image: systemImage.flatMap(Image.init(systemName:)))
    }

    public static func spectreBox(alignment: Alignment = .topTrailing, image: Image?,
                                  @ViewBuilder with background: @escaping () -> some View = { EmptyView() })
        -> Self {
        self.spectreBox(alignment: alignment) {
            ZStack(alignment: alignment) {
                background()
                image?
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .spectre.shape, maxHeight: .spectre.shape)
                    .rotationEffect(.degrees(alignment.horizontal.sign * -alignment.vertical.sign * 20.0))
                    .padding(-.spectre.margin)
                    .opacity(.short)
            }
        }
    }

    public static func spectreBox(alignment: Alignment = .center,
                                  @ViewBuilder with background: @escaping () -> some View = { EmptyView() })
        -> Self {
        Self(alignment: alignment, background: { AnyView(background()) })
    }
}

public struct SpectreBoxButtonStyle: PrimitiveButtonStyle {
    let alignment: Alignment
    var background: () -> AnyView?

    @Environment(\.multilineTextAlignment)
    private var multilineTextAlignment: TextAlignment
    @Environment(\.isEnabled)
    private var isEnabled
    @State
    private var isPressing = false
    @State
    private var isPressed = false

    public func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: self.multilineTextAlignment.horizontal, spacing: .spectre.padding) {
            configuration.label
        }
        .font(.spectre.callout)
        .padding(.spectre.margin)
        .frame(maxWidth: .infinity, alignment: self.multilineTextAlignment.horizontal.vertically())
        .animation(.default) { $0
            .background(alignment: self.alignment, content: self.background)
            .background(self.isEnabled ? Color.spectre.placeholder : .spectre.mute)
            .clipShape(ContainerRelativeShape())
            .overlay {
                ContainerRelativeShape()
                    .strokeBorder(Color.spectre.body)
                    .opacity(self.isPressed || self.isPressing ? .on : .off)
                    .paddingEffect(self.isPressed ? -.spectre.padding / 2 : .zero)
            }
            .containerShape(UnevenRoundedRectangle(
                topLeadingRadius: .spectre.margin, bottomLeadingRadius: .spectre.margin,
                bottomTrailingRadius: .zero, topTrailingRadius: .zero, style: .continuous
            ))
        }
        .animation(.default.delay(self.isPressing ? .zero : .short)) { $0
            .paddingEffect(self.isPressing ? -.spectre.padding / 2 : .zero)
        }
        ._onButtonGesture(pressing: {
            self.isPressing = $0
        }, perform: {
            self.isPressing = false
            self.isPressed = true
            configuration.trigger()
            Task {
                try? await Task.sleep(for: .seconds(.short))
                self.isPressed = false
            }
        })
        .padding(.trailing, -.spectre.margin)
//        .strikethrough(!self.isEnabled)
        .opacity(self.isEnabled ? .on : .short)
        .saturation(self.isEnabled ? .on : .off)
    }
}

/// - Toggle

extension ToggleStyle where Self == SpectreToggleStyle {
    public static var spectre: Self { Self() }
}

extension ToggleStyle where Self == SpectreBoxToggleStyle {
    public static func spectreBox() -> Self { Self() }
}

public struct SpectreToggleStyle: ToggleStyle {
    @Environment(\.isEnabled)
    private var isEnabled

    public func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            configuration.label
        }
        .buttonStyle(.spectre {
            Image(
                systemName: !self.isEnabled
                    ? "circle.slash"
                    : configuration.isMixed
                        ? "circle.fill"
                        : configuration.isOn
                            ? "checkmark"
                            : "xmark"
            )
            .transition(.symbolEffect)
            .animation(.default) { $0
                .font(.spectre.caption1)
                .padding(.spectre.padding / 2)
                .background { Circle().fill(configuration.isOn ? Color.spectre.selection : Color.spectre.mute) }
                .overlay { Circle().stroke(Color.spectre.selection) }
            }
        })
    }
}

public struct SpectreBoxToggleStyle: ToggleStyle {
    @Environment(\.isEnabled)
    private var isEnabled

    public func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: .spectre.padding) {
                configuration.label
                    .frame(maxWidth: .infinity, alignment: .leading)

                Color.spectre.placeholder
                    .frame(width: 1, height: .spectre.control - .spectre.padding * 2)

                Image(
                    systemName:
                    !self.isEnabled
                        ? "circle.slash"
                        : configuration.isMixed
                            ? "circle.fill"
                            : configuration.isOn
                                ? "checkmark"
                                : "xmark"
                )
                .transition(.symbolEffect)
                .animation(.default) { $0
                    .font(.spectre.caption1)
                    .padding(.spectre.padding / 2)
                    .background { Circle().fill(configuration.isOn ? Color.spectre.selection : Color.spectre.mute) }
                    .overlay { Circle().stroke(Color.spectre.selection) }
                }
            }
        }
        .buttonStyle(.spectreBox())
    }
}

/// - Label

extension LabelStyle where Self == SpectreLabelStyle {
    public static var spectre: Self { Self() }
}

public struct SpectreLabelStyle: LabelStyle {
    public var axis: Axis?

    public func with(axis: Axis?) -> Self {
        using(Self()) {
            $0.axis = axis
        }
    }

    public func makeBody(configuration: Configuration) -> some View {
        switch self.axis {
            case .horizontal:
                HStack(spacing: .spectre.padding / 2) {
                    self.content(configuration: configuration)
                }
            case .vertical:
                VStack(alignment: .leading, spacing: .spectre.padding / 2) {
                    self.content(configuration: configuration)
                }
            case .none:
                ViewThatFits(in: .vertical) {
                    HStack(spacing: .spectre.padding / 2) {
                        self.content(configuration: configuration)
                    }
                    VStack(alignment: .leading, spacing: .spectre.padding / 2) {
                        self.content(configuration: configuration)
                    }
                }
        }
    }

    @ViewBuilder
    public func content(configuration: Configuration) -> some View {
        configuration.icon
            .font(.spectre.callout)
        configuration.title
            .font(.spectre.caption2)
    }
}

/// - Group Box

extension GroupBoxStyle where Self == SpectreGroupBoxStyle {
    public static var spectre: Self { Self.spectre(with: {}) }

    public static func spectre(alignment: Alignment = .topTrailing, systemImage: String?) -> Self {
        self.spectre(alignment: alignment, image: systemImage.flatMap(Image.init(systemName:)))
    }

    public static func spectre(alignment: Alignment = .topTrailing, image: Image?) -> Self {
        self.spectre(alignment: alignment) {
            image?
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .spectre.shape, maxHeight: .spectre.shape)
                .rotationEffect(.degrees(alignment.horizontal.sign * -alignment.vertical.sign * 20.0))
                .padding(-.spectre.margin)
                .opacity(.short)
        }
    }

    public static func spectre(alignment: Alignment = .center, @ViewBuilder with background: @escaping () -> some View) -> Self {
        Self(alignment: alignment, background: { AnyView(background()) })
    }
}

public struct SpectreGroupBoxStyle: GroupBoxStyle {
    let alignment: Alignment
    var background: () -> AnyView?

    public func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: .spectre.padding) {
            HStack {
                configuration.label
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.spectre.headline)

            configuration.content
        }
        .padding(.spectre.margin)
        .background(alignment: self.alignment, content: self.background)
        .background(Color.spectre.shade)
        .clipShape(ContainerRelativeShape())
        .background(ContainerRelativeShape().stroke(Color.spectre.placeholder))
        .containerShape(UnevenRoundedRectangle(
            topLeadingRadius: .spectre.margin, bottomLeadingRadius: .spectre.margin,
            bottomTrailingRadius: .zero, topTrailingRadius: .zero, style: .continuous
        ))
        .padding(.trailing, -.spectre.margin - 1)
    }
}

/// - Labeled Content

extension LabeledContentStyle where Self == SpectreLabeledContentStyleHorizontal {
    public static var spectreHorizontal: Self { Self() }
}

extension LabeledContentStyle where Self == SpectreLabeledContentStyleVertical {
    public static var spectreVertical: Self { Self() }
}

extension LabeledContentStyle where Self == SpectreLabeledContentStyleCaptioned {
    public static var spectreCaptioned: Self { Self() }
}

public struct SpectreLabeledContentStyleHorizontal: LabeledContentStyle {
    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: .zero) {
            VStack { configuration.label }
                .font(.spectre.subheadline)

            Spacer()

            VStack { configuration.content }
                .font(.spectre.callout)
        }
        .padding(.leading, .spectre.padding / 2 + .spectre.padding)
        .background(alignment: .leading) {
            RoundedRectangle(cornerRadius: .infinity)
                .foregroundColor(.spectre.mute)
                .frame(width: .spectre.padding / 2)
        }
    }
}

public struct SpectreLabeledContentStyleVertical: LabeledContentStyle {
    @Environment(\.multilineTextAlignment)
    private var multilineTextAlignment: TextAlignment

    public func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: self.multilineTextAlignment.horizontal) {
            HStack { configuration.label }
                .font(.spectre.subheadline)
                .frame(maxWidth: .infinity, alignment: self.multilineTextAlignment.horizontal.vertically())

            HStack { configuration.content }
                .font(.spectre.callout)
        }
        .padding(self.multilineTextAlignment.horizontal.vertically().edges, .spectre.padding / 2 + .spectre.padding)
        .background(alignment: self.multilineTextAlignment.horizontal.vertically()) {
            if !self.multilineTextAlignment.horizontal.vertically().edges.isEmpty {
                RoundedRectangle(cornerRadius: .infinity)
                    .foregroundColor(.spectre.mute)
                    .frame(width: .spectre.padding / 2)
            }
        }
    }
}

public struct SpectreLabeledContentStyleCaptioned: LabeledContentStyle {
    @Environment(\.multilineTextAlignment)
    private var multilineTextAlignment: TextAlignment

    public func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: self.multilineTextAlignment.horizontal) {
            HStack { configuration.content }
                .font(.spectre.callout)
                .layoutPriority(1) // Prevents content compression when label exceeds 1 line.

            HStack { configuration.label }
                .font(.spectre.caption1)
                .foregroundStyle(Color.spectre.alternative)
                .frame(maxWidth: .infinity, alignment: self.multilineTextAlignment.horizontal.vertically())
        }
        .padding(self.multilineTextAlignment.horizontal.vertically().edges, .spectre.padding / 2 + .spectre.padding)
        .background(alignment: self.multilineTextAlignment.horizontal.vertically()) {
            if !self.multilineTextAlignment.horizontal.vertically().edges.isEmpty {
                RoundedRectangle(cornerRadius: .infinity)
                    .foregroundColor(.spectre.mute)
                    .frame(width: .spectre.padding / 2)
            }
        }
    }
}

/// - Control Group

extension ControlGroupStyle where Self == SpectreControlGroupStyleFlow {
    public static var spectre: Self { Self.spectre() }

    public static func spectre(alignment: Alignment = .center) -> Self {
        Self(alignment: alignment)
    }
}

public struct SpectreControlGroupStyleFlow: ControlGroupStyle {
    let alignment: Alignment

    public func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: self.alignment.horizontal, spacing: .spectre.padding) {
            HStack { configuration.label }
                .frame(maxWidth: .infinity, alignment: self.alignment)
                .font(.spectre.subheadline)

            WrappingHStack(alignment: self.alignment) { configuration.content }
                .removeWhenEmpty()
                .font(.spectre.callout)
                .padding(.spectre.margin)
                .background(Color.spectre.shade)
                .clipShape(ContainerRelativeShape())
                .background(ContainerRelativeShape().stroke(Color.spectre.placeholder))
                .containerShape(UnevenRoundedRectangle(
                    topLeadingRadius: .spectre.margin, bottomLeadingRadius: .spectre.margin,
                    bottomTrailingRadius: .zero, topTrailingRadius: .zero, style: .continuous
                ))
        }
        .padding(.trailing, -.spectre.margin - 1)
    }
}

/// - Form

extension FormStyle where Self == SpectreFormStyle {
    public static var spectre: Self { Self() }
}

public struct SpectreFormStyle: FormStyle {
    public func makeBody(configuration: Configuration) -> some View {
        List {
            configuration.content
                .listItemTint(.preferred(.spectre.alternative))
                .listRowSeparatorTint(Color.clear)
                .listRowBackground(Color.spectre.panel)
                .listSectionSeparatorTint(Color.clear)
                .listRowInsets(.border(.spectre.margin))
        }
        .shadow(color: .spectre.shadow, radius: .on)
        .environment(\.defaultMinListRowHeight, .zero)
        .environment(\.defaultMinListHeaderHeight, .zero)
        .environment(\.headerProminence, .increased)
        .listRowSpacing(.zero)
        .listSectionSpacing(.zero)
        .listStyle(.insetGrouped)
    }
}

// Private

extension Font {
    fileprivate static func custom(_ name: String, relativeTo textStyle: Font.TextStyle) -> Font {
        self.custom(name, size: UIFont.preferredFont(forTextStyle: textStyle.uiTextStyle).pointSize, relativeTo: textStyle)
    }
}

extension Font.TextStyle {
    fileprivate var uiTextStyle: UIFont.TextStyle {
        switch self {
            case .largeTitle:
                return .largeTitle
            case .title:
                return .title1
            case .title2:
                return .title2
            case .title3:
                return .title3
            case .headline:
                return .headline
            case .subheadline:
                return .subheadline
            case .body:
                return .body
            case .callout:
                return .callout
            case .footnote:
                return .footnote
            case .caption:
                return .caption1
            case .caption2:
                return .caption2
            @unknown default:
                return .body
        }
    }
}

/// - Preview

#if DEBUG
#Preview {
    Form {
        Text("Large Title")
            .font(.spectre.largeTitle)
            .listRowBackground(GradientView())

        Section("Section") {
            Button("Button") {}
                .listRowBackground(GradientView())
            Button("Disabled") {}.disabled(true)

            Button("Image Button", systemImage: "photo.circle") {}

            Button("Box Button") {}
                .buttonStyle(.spectreBox())
            Button("Box Background") {}
                .buttonStyle(.spectreBox(alignment: .leading, image: Image("avatar-0")) {
                    Color.spectre.selection
                })
            Button("Box Disabled") {}
                .buttonStyle(.spectreBox())
                .disabled(true)

            Toggle("Toggle", isOn: .constant(true))
            Toggle("Disabled", isOn: .constant(true)).disabled(true)
            Toggle("Box", isOn: .constant(true))
                .toggleStyle(.spectreBox())
            LabeledContent("Share anonymized issue information to enable quick resolution.") {
                Toggle("Toggle", systemImage: "photo.circle", isOn: .constant(false))
            }
            .labeledContentStyle(.spectreCaptioned)

            GroupBox("Group Box") {
                Text("Body Text")
            }

            GroupBox("Group Box with Image") {
                Text("Body Text")

                Label { Text("Label Title") } icon: { Text("Label  Icon") }
                Label("Image Label", systemImage: "photo.circle")

                Picker("Picker", selection: .constant("Foo")) {
                    ForEach(["Foo", "Bar"], id: \.self) {
                        Text($0)
                    }
                }

                LabeledContent("Label") {
                    Text("Content")
                }

                LabeledContent("Vertical Label") {
                    Text("Content")
                }.labeledContentStyle(.spectreVertical)

                LabeledContent("Captioned Label") {
                    Text("Centered Content")
                }.labeledContentStyle(.spectreCaptioned)
                    .multilineTextAlignment(.center)
            }.groupBoxStyle(.spectre(systemImage: "photo"))

            ControlGroup("Empty Group") {}
            ControlGroup("Control Group") {
                Text("Text1\nText2")
                Button("Button 1") {}
                Button("Button 2") {}
                Button("Button 3") {}
                Button("Button 4") {}
            }
        }
    }
    .navigationTitle("Spectre Theme")
    .toolbar {
        Button("Tool", systemImage: "gear") {}
        Button("Tool") {}
    }
    .spectreStyle()
}
#endif
