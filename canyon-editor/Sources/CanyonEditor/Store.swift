import Foundation
import Observation

/// Everything in the database, held in memory. At a few hundred rows there's no
/// reason to do anything cleverer: every write reloads the lot, so the lists and
/// the file can't drift apart.
@Observable
final class Store {
    private let db: Database
    let path: String

    private(set) var canyons: [Canyon] = []
    private(set) var events: [Event] = []
    private(set) var descents: [Descent] = []

    var errorMessage: String?

    init(path: String) throws {
        self.path = path
        self.db = try Database(path: path)
        reload()
    }

    // MARK: - Reading

    func reload() {
        attempt {
            canyons = try db.query("SELECT * FROM canyon").map(Canyon.init(row:))
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            events = try db.query("SELECT * FROM event").map(Event.init(row:))
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            descents = try db.query("SELECT * FROM descent").map(Descent.init(row:))
                .sorted { ($0.sortKey, $0.id ?? 0) > ($1.sortKey, $1.id ?? 0) }
        }
    }

    var regions: [String] {
        Array(Set(canyons.map(\.region))).filter { !$0.isEmpty }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    func canyon(_ id: Int64?) -> Canyon? {
        guard let id else { return nil }
        return canyons.first { $0.id == id }
    }

    func event(_ id: Int64?) -> Event? {
        guard let id else { return nil }
        return events.first { $0.id == id }
    }

    func canyonName(_ id: Int64?) -> String { canyon(id)?.name ?? "—" }
    func eventName(_ id: Int64?) -> String { event(id)?.name ?? "" }

    func descentCount(canyonID: Int64?) -> Int {
        descents.filter { $0.canyonID == canyonID }.count
    }

    func descentCount(eventID: Int64?) -> Int {
        descents.filter { $0.eventID == eventID }.count
    }

    // MARK: - Writing
    //
    // Each save returns the row's id, so a newly inserted row can stay selected.

    @discardableResult
    func save(_ canyon: Canyon) -> Int64? {
        let values: [SQLValue] = [
            .text(canyon.name.trimmingCharacters(in: .whitespaces)),
            .text(canyon.region.trimmingCharacters(in: .whitespaces)),
            .optionalText(canyon.aka),
            .optionalText(canyon.acaRating),
            .optionalText(canyon.ffmeRating),
            .optionalText(canyon.raps),
            .optionalInt(Int64(canyon.longestRapFt.trimmingCharacters(in: .whitespaces))),
            .optionalText(canyon.bestSeason),
            .optionalText(canyon.permits),
            .optionalText(canyon.coordinates),
            .optionalText(canyon.url),
            .optionalText(canyon.notes),
        ]
        let columns = """
            name, region, aka, aca_rating, ffme_rating, raps, longest_rap_ft, \
            best_season, permits, coordinates, url, notes
            """
        return write(id: canyon.id, table: "canyon", columns: columns, values: values)
    }

    @discardableResult
    func save(_ event: Event) -> Int64? {
        let values: [SQLValue] = [
            .text(event.name.trimmingCharacters(in: .whitespaces)),
            .optionalText(event.startDate),
            .optionalText(event.endDate),
            .optionalText(event.notes),
        ]
        return write(id: event.id, table: "event",
                     columns: "name, start_date, end_date, notes", values: values)
    }

    @discardableResult
    func save(_ descent: Descent) -> Int64? {
        let values: [SQLValue] = [
            .optionalInt(descent.canyonID),
            .optionalInt(descent.eventID),
            .text(descent.date.trimmingCharacters(in: .whitespaces)),
            .optionalText(descent.route),
            .text(descent.role),
            .optionalText(descent.flow),
            .optionalText(descent.conditions),
            .optionalText(descent.partners),
            .optionalText(descent.notes),
        ]
        let columns = "canyon_id, event_id, date, route, role, flow, conditions, partners, notes"
        return write(id: descent.id, table: "descent", columns: columns, values: values)
    }

    func delete(canyonID id: Int64) {
        let used = descentCount(canyonID: id)
        guard used == 0 else {
            errorMessage = "\(canyonName(id)) still has \(used) descent\(used == 1 ? "" : "s"). "
                + "Delete or reassign those first."
            return
        }
        delete(table: "canyon", id: id)
    }

    func delete(eventID id: Int64) {
        // Descents outlive their event; they just stop being part of one.
        attempt {
            try db.execute("UPDATE descent SET event_id = NULL WHERE event_id = ?", [.int(id)])
            try db.execute("DELETE FROM event WHERE id = ?", [.int(id)])
            reload()
        }
    }

    func delete(descentID id: Int64) {
        delete(table: "descent", id: id)
    }

    // MARK: - Plumbing

    /// One INSERT/UPDATE builder for all three tables: same column list, same
    /// values, only the statement shape differs.
    private func write(id: Int64?, table: String, columns: String, values: [SQLValue]) -> Int64? {
        let names = columns.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        var saved: Int64?
        attempt {
            if let id {
                let assignments = names.map { "\($0) = ?" }.joined(separator: ", ")
                try db.execute("UPDATE \(table) SET \(assignments) WHERE id = ?",
                               values + [.int(id)])
                saved = id
            } else {
                let placeholders = names.map { _ in "?" }.joined(separator: ", ")
                saved = try db.execute(
                    "INSERT INTO \(table) (\(columns)) VALUES (\(placeholders))", values)
            }
            reload()
        }
        return saved
    }

    private func delete(table: String, id: Int64) {
        attempt {
            try db.execute("DELETE FROM \(table) WHERE id = ?", [.int(id)])
            reload()
        }
    }

    /// Database errors are all the same kind of problem here -- show the message
    /// and leave the in-memory copy alone.
    private func attempt(_ body: () throws -> Void) {
        do {
            try body()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
