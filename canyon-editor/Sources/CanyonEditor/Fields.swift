import SwiftUI

/// A text field that turns red while its contents wouldn't survive the schema.
struct ValidatedField: View {
    let label: String
    @Binding var text: String
    let hint: String
    let isValid: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            TextField(label, text: $text)
                .font(.body.monospaced())
                .foregroundStyle(isValid ? Color.primary : Color.red)
            Text(hint)
                .foregroundStyle(.secondary)
        }
    }
}

/// Free text plus a menu of the values already in use -- the schema keeps these
/// columns as plain strings, so neither a picker nor a lookup table would do.
struct ComboField: View {
    let label: String
    @Binding var text: String
    let options: [String]

    var body: some View {
        LabeledContent(label) {
            HStack(spacing: 4) {
                TextField(label, text: $text)
                    .labelsHidden()
                Menu {
                    ForEach(options, id: \.self) { option in
                        Button(option) { text = option }
                    }
                } label: {
                    Image(systemName: "chevron.down")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .disabled(options.isEmpty)
            }
        }
    }
}

/// A picker over a fixed vocabulary, with an empty option when the column is
/// nullable, and room for a value the vocabulary doesn't know about yet.
struct VocabularyPicker: View {
    let label: String
    @Binding var selection: String
    let options: [String]
    var allowsEmpty = true

    var body: some View {
        Picker(label, selection: $selection) {
            if allowsEmpty { Text("—").tag("") }
            ForEach(options, id: \.self) { Text($0).tag($0) }
            if !selection.isEmpty && !options.contains(selection) {
                Text(selection).tag(selection)
            }
        }
    }
}

struct NotesField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        LabeledContent(label) {
            TextEditor(text: $text)
                .font(.body)
                .frame(minHeight: 70)
                .border(Color.secondary.opacity(0.3))
        }
    }
}

/// The right-hand side before anything is selected.
struct EmptyDetail: View {
    let message: String

    var body: some View {
        VStack {
            Spacer()
            Text(message).foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
