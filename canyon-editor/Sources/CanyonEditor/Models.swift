import Foundation

// Vocabularies, duplicated from lib/canyonlog.js -- they're plain strings in the
// schema, so the site and this editor each keep their own copy. Keep in sync.
enum Vocabulary {
    static let roles = [
        "student", "participant", "peer leader",
        "assistant guide", "instructor", "lead guide",
    ]
    static let flows = ["dry", "low", "mod-low", "mod", "mod-high", "high"]
    static let seasons = ["spring", "summer", "fall", "winter"]
}

/// The four date forms descent.date accepts, per the CHECK in data/schema.sql.
/// Mirrors parseDate() in lib/canyonlog.js, minus the display formatting.
enum FuzzyDate {
    static let hint = "2025-08-16 · 2025-08 · 2025-fall · 2025"

    static func isValid(_ value: String) -> Bool {
        sortKey(value) != nil
    }

    /// First day of the period the date names, so mixed precisions interleave.
    /// nil for anything the schema would reject.
    static func sortKey(_ value: String) -> String? {
        let s = value.trimmingCharacters(in: .whitespaces)

        if let m = match(s, #"^(\d{4})-(\d{2})-(\d{2})$"#) {
            guard let month = Int(m[2]), (1...12).contains(month),
                  let day = Int(m[3]), (1...31).contains(day) else { return nil }
            return s
        }
        if let m = match(s, #"^(\d{4})-(\d{2})$"#) {
            guard let month = Int(m[2]), (1...12).contains(month) else { return nil }
            return "\(m[1])-\(m[2])-01"
        }
        if let m = match(s, #"^(\d{4})-(spring|summer|fall|winter)$"#) {
            let months = ["spring": "03", "summer": "06", "fall": "09", "winter": "12"]
            return "\(m[1])-\(months[m[2]]!)-01"
        }
        if let m = match(s, #"^(\d{4})$"#) {
            return "\(m[1])-01-01"
        }
        return nil
    }

    /// An exact YYYY-MM-DD, which is all event.start_date / end_date accept.
    static func isValidExactOrEmpty(_ value: String) -> Bool {
        let s = value.trimmingCharacters(in: .whitespaces)
        if s.isEmpty { return true }
        guard let m = match(s, #"^(\d{4})-(\d{2})-(\d{2})$"#) else { return false }
        guard let month = Int(m[2]), (1...12).contains(month),
              let day = Int(m[3]), (1...31).contains(day) else { return false }
        return true
    }

    private static func match(_ s: String, _ pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let m = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s))
        else { return nil }
        return (0..<m.numberOfRanges).map { i in
            Range(m.range(at: i), in: s).map { String(s[$0]) } ?? ""
        }
    }
}

// The three tables. Every text column is a non-optional String: empty means
// "not filled in", and Database.SQLValue.optionalText turns that back into NULL
// on the way out. Saves the forms a pile of Optional binding.

struct Canyon: Identifiable, Equatable {
    var id: Int64?
    var name = ""
    var region = ""
    var aka = ""
    var acaRating = ""
    var ffmeRating = ""
    var raps = ""
    var longestRapFt = ""
    var bestSeason = ""
    var permits = ""
    var coordinates = ""
    var url = ""
    var notes = ""

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !region.trimmingCharacters(in: .whitespaces).isEmpty
            && (longestRapFt.trimmingCharacters(in: .whitespaces).isEmpty
                || Int64(longestRapFt.trimmingCharacters(in: .whitespaces)) != nil)
    }

    init(id: Int64? = nil) { self.id = id }

    init(row: Row) {
        id = row.int("id")
        name = row.string("name")
        region = row.string("region")
        aka = row.string("aka")
        acaRating = row.string("aca_rating")
        ffmeRating = row.string("ffme_rating")
        raps = row.string("raps")
        longestRapFt = row.int("longest_rap_ft").map(String.init) ?? ""
        bestSeason = row.string("best_season")
        permits = row.string("permits")
        coordinates = row.string("coordinates")
        url = row.string("url")
        notes = row.string("notes")
    }
}

struct Event: Identifiable, Equatable {
    var id: Int64?
    var name = ""
    var startDate = ""
    var endDate = ""
    var notes = ""

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && FuzzyDate.isValidExactOrEmpty(startDate)
            && FuzzyDate.isValidExactOrEmpty(endDate)
    }

    init(id: Int64? = nil) { self.id = id }

    init(row: Row) {
        id = row.int("id")
        name = row.string("name")
        startDate = row.string("start_date")
        endDate = row.string("end_date")
        notes = row.string("notes")
    }
}

struct Descent: Identifiable, Equatable {
    var id: Int64?
    var canyonID: Int64?
    var eventID: Int64?
    var date = ""
    var route = ""
    var role = "participant"
    var flow = ""
    var conditions = ""
    var partners = ""
    var notes = ""

    var isValid: Bool {
        canyonID != nil && FuzzyDate.isValid(date) && !role.isEmpty
    }

    var sortKey: String { FuzzyDate.sortKey(date) ?? "0000-00-00" }

    init(id: Int64? = nil) { self.id = id }

    init(row: Row) {
        id = row.int("id")
        canyonID = row.int("canyon_id")
        eventID = row.int("event_id")
        date = row.string("date")
        route = row.string("route")
        role = row.string("role")
        flow = row.string("flow")
        conditions = row.string("conditions")
        partners = row.string("partners")
        notes = row.string("notes")
    }
}
