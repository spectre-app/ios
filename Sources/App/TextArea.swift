//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import SwiftUI

struct TextArea: View {
    var prompt = ""
    @Binding
    var text: String

    @FocusState
    private var isFocused: Bool
    @Environment(\.lineLimit)
    private var lineLimit: Int?
    private var lines: CGFloat { CGFloat(self.lineLimit ?? 3) }
    private var height: CGFloat {
        UIFont.preferredFont(forTextStyle: .body).lineHeight * (self.lines + 0.3 * self.lines) + 16
    }

    var body: some View {
        TextEditor(text: Binding(
            get: { self.text.nonEmpty ?? (self.isFocused ? "" : self.prompt) },
            set: { self.text = $0 }
        ))
        .textEditorStyle(.plain)
        .font(self.text.isEmpty && !self.isFocused ? .spectre.caption1 : nil)
        .focused(self.$isFocused)
        .foregroundStyle(self.text.isEmpty ? Color.spectre.alternative : Color.spectre.body)
        .frame(height: self.height, alignment: .topLeading)
        .padding(.spectre.padding / 2)
        .background(Color.spectre.backdrop)
        .cornerRadius(.spectre.spacer)
        .textFieldStyle(.plain)
    }
}

struct TextField: View {
    var prompt = ""
    @Binding
    var text: String

    var body: some View {
        SwiftUI.TextField(
            "", text: self.$text, prompt:
            Text(self.prompt)
                .foregroundStyle(Color.spectre.alternative)
                .font(.spectre.caption1)
        )
        .foregroundStyle(Color.spectre.body)
        .padding(.spectre.padding)
        .background(Color.spectre.backdrop)
        .cornerRadius(.spectre.spacer)
    }
}

struct SecureField: View {
    var prompt = ""
    @Binding
    var text: String

    var body: some View {
        SwiftUI.SecureField(
            "", text: self.$text, prompt:
            Text(self.prompt)
                .foregroundStyle(Color.spectre.alternative)
                .font(.spectre.caption1)
        )
        .textContentType(.password)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .keyboardType(.asciiCapable)
        .foregroundStyle(Color.spectre.body)
        .padding(.spectre.padding)
        .background(Color.spectre.backdrop)
        .cornerRadius(.spectre.spacer)
    }
}

#if DEBUG
#Preview {
    @Previewable @State
    var empty = ""
    @Previewable @State
    var text = "1\n2\n3\n4\n5\n6\n7\n8\n9"

    return Form {
        Text("1 2 3 4")
        LabeledContent("With prompt") {
            TextArea(prompt: "Enter a value", text: $empty)
            TextField(prompt: "Enter a value", text: $empty)
            SecureField(prompt: "Enter a value", text: $empty)
        }

        LabeledContent("Without prompt") {
            TextArea(text: $text)
            TextField(text: $text)
            SecureField(text: $text)
        }

        LabeledContent("5 lines") {
            TextArea(text: $text)
                .lineLimit(5)
        }

        LabeledContent("1 line") {
            TextArea(text: $text)
                .lineLimit(1)
        }
    }
    .spectreStyle()
}
#endif
