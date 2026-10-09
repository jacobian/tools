import SwiftUI

struct DescentsPane: View {
    let store: Store

    var body: some View {
        RecordPane(
            items: store.descents,
            idOf: { $0.id },
            assignID: { $0.id = $1 },
            matches: { descent, needle in
                [
                    descent.date, descent.route, descent.role, descent.flow,
                    descent.conditions, descent.partners, descent.notes,
                    store.canyonName(descent.canyonID), store.eventName(descent.eventID),
                ].contains { $0.lowercased().contains(needle) }
            },
            isValid: \.isValid,
            makeNew: { Descent() },
            save: { store.save($0) },
            delete: { store.delete(descentID: $0) },
            describe: { "\($0.date) · \(store.canyonName($0.canyonID))" },
            row: { descent in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(descent.date)
                        .font(.body.monospaced())
                        .frame(width: 100, alignment: .leading)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.canyonName(descent.canyonID)
                             + (descent.route.isEmpty ? "" : " (\(descent.route))"))
                        Text(subtitle(descent))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            },
            form: { descent in
                Form {
                    Picker("Canyon", selection: descent.canyonID) {
                        Text("Choose…").tag(Int64?.none)
                        ForEach(store.canyons) { canyon in
                            Text(canyon.name).tag(canyon.id)
                        }
                    }
                    ValidatedField(
                        label: "Date", text: descent.date,
                        hint: FuzzyDate.hint,
                        isValid: FuzzyDate.isValid(descent.wrappedValue.date))
                    TextField("Route", text: descent.route)
                    VocabularyPicker(label: "Role", selection: descent.role,
                                     options: Vocabulary.roles, allowsEmpty: false)
                    VocabularyPicker(label: "Flow", selection: descent.flow,
                                     options: Vocabulary.flows)
                    Picker("Event", selection: descent.eventID) {
                        Text("None").tag(Int64?.none)
                        ForEach(store.events) { event in
                            Text(event.name).tag(event.id)
                        }
                    }
                    TextField("Conditions", text: descent.conditions)
                    TextField("Partners", text: descent.partners)
                    NotesField(label: "Notes", text: descent.notes)
                }
                .formStyle(.grouped)
            }
        )
    }

    private func subtitle(_ descent: Descent) -> String {
        var parts = [descent.role]
        if !descent.flow.isEmpty { parts.append(descent.flow) }
        let event = store.eventName(descent.eventID)
        if !event.isEmpty { parts.append(event) }
        return parts.joined(separator: " · ")
    }
}

struct CanyonsPane: View {
    let store: Store

    var body: some View {
        RecordPane(
            items: store.canyons,
            idOf: { $0.id },
            assignID: { $0.id = $1 },
            matches: { canyon, needle in
                [canyon.name, canyon.region, canyon.aka, canyon.acaRating,
                 canyon.ffmeRating, canyon.bestSeason, canyon.notes]
                    .contains { $0.lowercased().contains(needle) }
            },
            isValid: \.isValid,
            makeNew: { Canyon() },
            save: { store.save($0) },
            delete: { store.delete(canyonID: $0) },
            describe: { $0.name },
            row: { canyon in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(canyon.name)
                        Text(canyon.region).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(store.descentCount(canyonID: canyon.id))")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            },
            form: { canyon in
                Form {
                    TextField("Name", text: canyon.name)
                    ComboField(label: "Region", text: canyon.region, options: store.regions)
                    TextField("Also known as", text: canyon.aka)
                    Section {
                        TextField("ACA rating", text: canyon.acaRating)
                            .help("technical 1-4, water A-C (subgrades C1-C4), time I-VI, "
                                  + "then risk: \"3C3 IV R\"")
                        TextField("FFME rating", text: canyon.ffmeRating)
                            .help("vertical v1-v7, aquatic a1-a7, commitment I-VI: \"v4a4 III\"")
                        TextField("Raps", text: canyon.raps)
                            .help("a range, in practice: \"4-7\"")
                        TextField("Longest rap (ft)", text: canyon.longestRapFt)
                            .foregroundStyle(canyon.wrappedValue.isValid ? Color.primary : Color.red)
                    }
                    Section {
                        TextField("Best season", text: canyon.bestSeason)
                        TextField("Permits", text: canyon.permits)
                        TextField("Coordinates", text: canyon.coordinates)
                            .help("\"45.6432, -122.0926\"")
                        TextField("URL", text: canyon.url)
                    }
                    NotesField(label: "Notes", text: canyon.notes)
                }
                .formStyle(.grouped)
            }
        )
    }
}

struct EventsPane: View {
    let store: Store

    var body: some View {
        RecordPane(
            items: store.events,
            idOf: { $0.id },
            assignID: { $0.id = $1 },
            matches: { event, needle in
                [event.name, event.startDate, event.endDate, event.notes]
                    .contains { $0.lowercased().contains(needle) }
            },
            isValid: \.isValid,
            makeNew: { Event() },
            save: { store.save($0) },
            delete: { store.delete(eventID: $0) },
            describe: { "\($0.name) — its descents keep their dates but lose the event" },
            row: { event in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(event.name)
                        Text(dateRange(event)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(store.descentCount(eventID: event.id))")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            },
            form: { event in
                Form {
                    TextField("Name", text: event.name)
                    ValidatedField(
                        label: "Start", text: event.startDate,
                        hint: "2025-08-16, or empty",
                        isValid: FuzzyDate.isValidExactOrEmpty(event.wrappedValue.startDate))
                    ValidatedField(
                        label: "End", text: event.endDate,
                        hint: "2025-08-16, or empty",
                        isValid: FuzzyDate.isValidExactOrEmpty(event.wrappedValue.endDate))
                    NotesField(label: "Notes", text: event.notes)
                }
                .formStyle(.grouped)
            }
        )
    }

    private func dateRange(_ event: Event) -> String {
        switch (event.startDate.isEmpty, event.endDate.isEmpty) {
        case (true, true): return "undated"
        case (false, true): return event.startDate
        case (true, false): return event.endDate
        case (false, false): return "\(event.startDate) – \(event.endDate)"
        }
    }
}
