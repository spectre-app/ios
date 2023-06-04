//
//  SpectreTheme.swift
//  Spectre
//
//  Created by Maarten Billemont on 2023-03-05.
//  Copyright © 2023 Lyndir. All rights reserved.
//

import SwiftUI
import WrappingHStack

/// - Fonts and Colors

public extension Font {
    static let spectre = SpectreFont()

    struct SpectreFont {
        let largeTitle = Font.custom("Poppins", relativeTo: .largeTitle).weight(.black)
        let title1 = Font.custom("Poppins", relativeTo: .title).weight(.regular)
        let title2 = Font.custom("Poppins", relativeTo: .title2).weight(.medium)
        let title3 = Font.custom("Poppins", relativeTo: .title3).weight(.regular)
        let headline = Font.custom("Poppins", relativeTo: .headline).weight(.semibold)
        let subheadline = Font.custom("Poppins", relativeTo: .subheadline).weight(.medium)
        let body = Font.custom("Poppins", relativeTo: .body).weight(.light)
        let callout = Font.custom("Poppins", relativeTo: .callout).weight(.regular)
        let caption1 = Font.custom("Poppins", relativeTo: .caption).weight(.regular)
        let caption2 = Font.custom("Poppins", relativeTo: .caption2).weight(.medium)
        let footnote = Font.custom("Poppins", relativeTo: .footnote).weight(.medium)
        let password = Font.custom("Source Code Pro", relativeTo: .largeTitle)
        let mono = Font.custom("Source Code Pro", relativeTo: .body).monospacedDigit().weight(.thin)
    }
}

public extension Color {
    static let spectre = SpectreColor()

    struct SpectreColor {
        let body = Color("spectre.primary")
        let selection = Color("spectre.primary").opacity(.short)
        let tint = Color("spectre.secondary")
        let secondary = Color("spectre.secondary").opacity(.long)
        let placeholder = Color("spectre.secondary").opacity(.short)
        let mute = Color("spectre.secondary").opacity(.short * .short * .short)
        let backdrop = Color("spectre.primaryBackground")
        let panel = Color("spectre.secondaryBackground")
        let shadow = Color("spectre.primaryBackground").opacity(.long)
        let shade = Color("spectre.secondaryBackground").opacity(.long)
    }
}

/// - App

public extension View {
    func appStyle() -> some View {
        NavigationStack {
            self
        }

        // Style
        .backgroundStyle(Gradient(colors: [.spectre.backdrop, .spectre.panel]))
        .foregroundStyle(Color.spectre.body, Color.spectre.tint, Color.spectre.placeholder)
        .labeledContentStyle(.spectreHorizontal)
        .buttonStyle(.spectre)
        .controlGroupStyle(.spectre)
        //.datePickerStyle(.spectre)
        //.formStyle(.spectre)
        //.menuStyle(.spectre)
        //.pickerStyle(.spectre)
        //.toggleStyle(.spectre)
        //.gaugeStyle(.spectre)
        //.progressViewStyle(.spectre)
        .labelStyle(.spectre)
        .listStyle(.plain)
        //.textFieldStyle(.spectre)
        //.textEditorStyle(.spectre)
        //.tableStyle(.spectre)
        //.disclosureGroupStyle(.spectre)
        //.navigationSplitViewStyle(.spectre)
        //.tabViewStyle(.spectre)
        .groupBoxStyle(.spectre)
        //.indexViewStyle(.spectre)
        .font(.spectre.body)
    }
}

/// - Button

public extension ButtonStyle where Self == SpectreButtonStyle {
    static var spectre: Self { Self() }
}

public struct SpectreButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
        }
        .font(.spectre.callout)
        .padding(8)
        .frame(minWidth: 44, minHeight: 44)
        .background {
            RoundedRectangle(cornerRadius: 12).fill(Color.spectre.mute)
        }
    }
}

/// - Label

public extension LabelStyle where Self == SpectreLabelStyle {
    static var spectre: Self { Self() }
}

public struct SpectreLabelStyle: LabelStyle {
    public func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.icon
            configuration.title
        }
        .font(.spectre.callout)
    }
}

/// - Group Box

public extension GroupBoxStyle where Self == SpectreGroupBoxStyle {
    static var spectre: Self { Self.spectre(with: {}) }

    static func spectre(systemImage: String) -> Self {
        Self.spectre(alignment: .topTrailing) {
            Image(systemName: systemImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 150, maxHeight: 150)
                .rotationEffect(.degrees(20))
                .offset(x: 20, y: -20)
                .opacity(.short)
        }
    }

    static func spectre(alignment: Alignment = .center, @ViewBuilder with background: @escaping () -> some View) -> Self {
        Self(alignment: alignment, background: { AnyView(background()) })
    }
}

public struct SpectreGroupBoxStyle: GroupBoxStyle {
    let alignment: Alignment
    var background: () -> AnyView?

    public func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                configuration.label
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.spectre.headline)

            configuration.content
        }
        .padding(20)
        .background {
            ZStack(alignment: self.alignment) {
                Color.spectre.panel

                self.background()
                    .opacity(.short)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.leading, 20)
    }
}

/// - Group Box

public extension LabeledContentStyle where Self == SpectreLabeledContentStyleHorizontal {
    static var spectreHorizontal: Self { Self() }
}

public extension LabeledContentStyle where Self == SpectreLabeledContentStyleVertical {
    static var spectreVertical: Self { Self() }
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
        .padding(.leading, 20)
        .background(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .frame(width: 4).frame(width: 20)
                .foregroundColor(.spectre.mute)
        }
    }
}

public struct SpectreLabeledContentStyleVertical: LabeledContentStyle {
    public func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading) {
            HStack { configuration.label }
                .font(.spectre.subheadline)

            HStack { configuration.content }
                .font(.spectre.callout)
        }
        .padding(.leading, 20)
        .background(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .frame(width: 4).frame(width: 20)
                .foregroundColor(.spectre.mute)
        }
    }
}

/// - Group Box

public extension ControlGroupStyle where Self == SpectreControlGroupStyleFlow {
    static var spectre: Self { Self.spectre() }

    static func spectre(alignment: Alignment = .center) -> Self {
        Self(alignment: alignment)
    }
}

public struct SpectreControlGroupStyleFlow: ControlGroupStyle {
    let alignment: Alignment

    public func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: self.alignment.horizontal) {
            HStack { configuration.label }
                .font(.spectre.subheadline)

            WrappingHStack(alignment: self.alignment) { configuration.content }
                .font(.spectre.callout)
        }
    }
}

// Private

private extension Font {
    static func custom(_ name: String, relativeTo textStyle: Font.TextStyle) -> Font {
        custom(name, size: UIFont.preferredFont(forTextStyle: textStyle.uiTextStyle).pointSize, relativeTo: textStyle)
    }
}

private extension Font.TextStyle {
    var uiTextStyle: UIFont.TextStyle {
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

#Preview {
    List {
        Text("Large Title")
            .font(.spectre.largeTitle)
            .listRowBackground(Color.clear)

        Section("Section") {
            Group {
                Button("Button") {}

                Button("Image Button", systemImage: "photo.circle.fill") {}

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
                }.groupBoxStyle(.spectre(systemImage: "photo"))

                ControlGroup("Control Group") {
                    Text("Text")
                    Button("Button 1") {}
                    Button("Button 2") {}
                    Button("Button 3") {}
                    Button("Button 4") {}
                }
            }
            .listRowBackground(Color.clear)
        }
    }
    .background()
    .appStyle()
}
