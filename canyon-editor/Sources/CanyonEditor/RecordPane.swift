import SwiftUI

/// List on the left, form on the right, for one table.
///
/// All three tables want the same behaviour -- search, add, delete, and edits
/// that are written when you move on -- so it lives here once and the panes
/// supply only the row, the form, and the SQL-facing closures.
///
/// Edits go to a draft copy. Moving to another row saves it first; if it isn't
/// valid the move is refused and the offending field is already showing red,
/// which is why `isValid` is a closure rather than something the form reports.
struct RecordPane<Item: Equatable, RowContent: View, FormContent: View>: View {
    let items: [Item]
    let idOf: (Item) -> Int64?
    let assignID: (inout Item, Int64) -> Void
    let matches: (Item, String) -> Bool
    let isValid: (Item) -> Bool
    let makeNew: () -> Item
    let save: (Item) -> Int64?
    let delete: (Int64) -> Void
    let describe: (Item) -> String
    @ViewBuilder let row: (Item) -> RowContent
    @ViewBuilder let form: (Binding<Item>) -> FormContent

    @State private var selectedID: Int64?
    @State private var draft: Item?
    @State private var saved: Item?
    @State private var search = ""
    @State private var pendingDelete: Int64?

    private var filtered: [Item] {
        let needle = search.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return items }
        return items.filter { matches($0, needle.lowercased()) }
    }

    private var isDirty: Bool { draft != saved }

    /// List wants a non-optional identity. Rows always have one: a draft that
    /// hasn't been saved yet isn't in `items`.
    private struct Entry: Identifiable {
        let id: Int64
        let item: Item
    }

    private var entries: [Entry] {
        filtered.compactMap { item in idOf(item).map { Entry(id: $0, item: item) } }
    }

    /// Nil while a never-saved row is being filled in, so the list shows no
    /// highlight until it lands in the database.
    private var listSelection: Binding<Int64?> {
        Binding(
            get: { selectedID },
            set: { newValue in
                guard commit() else { return }
                select(newValue)
            }
        )
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                TextField("Search", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .padding(8)

                List(entries, selection: listSelection) { entry in
                    row(entry.item)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))

                Divider()
                HStack(spacing: 4) {
                    Button { addNew() } label: { Image(systemName: "plus") }
                        .help("New")
                    Button { pendingDelete = selectedID } label: { Image(systemName: "minus") }
                        .help("Delete")
                        .disabled(selectedID == nil)
                    Spacer()
                    Text("\(entries.count)").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .padding(6)
            }
            .frame(minWidth: 240, idealWidth: 300, maxWidth: 420)

            Group {
                if draft != nil {
                    VStack(spacing: 0) {
                        form(Binding(get: { draft! }, set: { draft = $0 }))
                        Divider()
                        HStack {
                            Spacer()
                            Button("Revert") { draft = saved }
                                .disabled(!isDirty || saved == nil)
                            Button("Save") { _ = commit() }
                                .keyboardShortcut("s")
                                .disabled(!isDirty || !isValid(draft!))
                        }
                        .padding(10)
                    }
                } else {
                    EmptyDetail(message: "Nothing selected")
                }
            }
            .frame(minWidth: 420)
        }
        .confirmationDialog(
            "Delete this record?",
            isPresented: Binding(get: { pendingDelete != nil },
                                 set: { if !$0 { pendingDelete = nil } })
        ) {
            Button("Delete", role: .destructive) {
                if let id = pendingDelete {
                    delete(id)
                    select(nil)
                }
                pendingDelete = nil
            }
        } message: {
            Text(pendingDelete.flatMap { id in
                items.first { idOf($0) == id }.map(describe)
            } ?? "")
        }
    }

    private func select(_ id: Int64?) {
        selectedID = id
        draft = id.flatMap { wanted in items.first { idOf($0) == wanted } }
        saved = draft
    }

    private func addNew() {
        guard commit() else { return }
        selectedID = nil
        draft = makeNew()
        saved = nil
    }

    /// Writes the draft if it has changed. False means it couldn't be written,
    /// and the caller should leave the selection where it is.
    @discardableResult
    private func commit() -> Bool {
        guard var current = draft, isDirty else { return true }
        guard isValid(current) else { return false }
        if let newID = save(current) { assignID(&current, newID) }
        draft = current
        saved = current
        selectedID = idOf(current)
        return true
    }
}
