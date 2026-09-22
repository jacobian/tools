/**
 * Shaping the canyon log for display. Pure functions -- no database, so the
 * fiddly parts (date precision, ordering, counting) are testable on their own.
 * See lib/canyonlog.test.js.
 */

// Roles in order of increasing responsibility. The last three are formal
// leadership, which is what a canyon's "3 as guide" counts.
const ROLES = [
  "student",
  "participant",
  "peer leader",
  "assistant guide",
  "instructor",
  "lead guide",
];
const FORMAL_ROLES = new Set(["assistant guide", "instructor", "lead guide"]);

// Flows in order of increasing water.
const FLOWS = ["dry", "low", "mod-low", "mod", "mod-high", "high"];

const MONTHS = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
];

// A season is stored as its first month.
const SEASON_MONTHS = { spring: 3, summer: 6, fall: 9, winter: 12 };

// Fuzzier dates sort later within the same period, so a vague "August 2025"
// lands after every dated August entry rather than on top of them.
const PRECISION_ORDER = { day: 0, month: 1, season: 2, year: 3 };

/**
 * Read a stored date into `{ precision, display, sortKey }`.
 *
 * Accepts "2025-08-16", "2025-08", "2025-fall" and "2025" -- the same four
 * forms the descent.date CHECK constraint allows. sortKey is always the first
 * day of the period, so entries of differing precision interleave sensibly.
 */
function parseDate(value) {
  const s = typeof value === "string" ? value.trim() : "";

  let m;
  if ((m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s))) {
    const [, year, month, day] = m;
    const monthName = MONTHS[Number(month) - 1];
    if (monthName && Number(day) >= 1 && Number(day) <= 31) {
      return {
        precision: "day",
        display: `${Number(day)} ${monthName} ${year}`,
        sortKey: s,
      };
    }
  } else if ((m = /^(\d{4})-(\d{2})$/.exec(s))) {
    const [, year, month] = m;
    const monthName = MONTHS[Number(month) - 1];
    if (monthName) {
      return {
        precision: "month",
        display: `${monthName} ${year}`,
        sortKey: `${year}-${month}-01`,
      };
    }
  } else if ((m = /^(\d{4})-(spring|summer|fall|winter)$/.exec(s))) {
    const [, year, season] = m;
    const month = String(SEASON_MONTHS[season]).padStart(2, "0");
    return {
      precision: "season",
      display: `${season[0].toUpperCase()}${season.slice(1)} ${year}`,
      sortKey: `${year}-${month}-01`,
    };
  } else if ((m = /^(\d{4})$/.exec(s))) {
    return { precision: "year", display: s, sortKey: `${s}-01-01` };
  }

  throw new Error(`unrecognised date: ${JSON.stringify(value)}`);
}

/** Newest first; on a tie the more precise date wins. */
function byDateDesc(a, b) {
  if (a.date.sortKey !== b.date.sortKey) {
    return a.date.sortKey < b.date.sortKey ? 1 : -1;
  }
  return PRECISION_ORDER[a.date.precision] - PRECISION_ORDER[b.date.precision];
}

/** Attach a parsed date, leaving the row otherwise untouched. */
function dated(descents) {
  return descents.map((d) => ({ ...d, date: parseDate(d.date) }));
}

/**
 * The chronological log: newest first, with each event's descents collected
 * into a single entry positioned at that event's most recent descent.
 *
 * Returns entries of either shape:
 *   { type: "descent", ...descent }
 *   { type: "event", id, name, event, date, descents: [...] }
 */
function buildLog(descents) {
  const entries = [];
  const events = new Map();

  for (const d of dated(descents)) {
    if (!d.event) {
      entries.push({ type: "descent", ...d });
      continue;
    }
    let group = events.get(d.event.id);
    if (!group) {
      // Position the group at its newest descent, filled in below.
      group = {
        type: "event",
        id: d.event.id,
        name: d.event.name,
        event: d.event,
        date: d.date,
        descents: [],
      };
      events.set(d.event.id, group);
      entries.push(group);
    }
    group.descents.push(d);
    if (byDateDesc(d, group) < 0) group.date = d.date;
  }

  for (const group of events.values()) group.descents.sort(byDateDesc);
  return entries.sort(byDateDesc);
}

/**
 * One row per canyon: how many times, how many of those leading, when, and
 * which routes. Ordered by descent count, then name.
 */
function rollupCanyons(descents) {
  const rows = new Map();

  for (const d of dated(descents)) {
    let row = rows.get(d.canyon.id);
    if (!row) {
      row = {
        canyon: d.canyon,
        count: 0,
        formalCount: 0,
        routes: [],
        first: d.date,
        last: d.date,
        descents: [],
      };
      rows.set(d.canyon.id, row);
    }
    row.count += 1;
    if (FORMAL_ROLES.has(d.role)) row.formalCount += 1;
    if (d.route && !row.routes.includes(d.route)) row.routes.push(d.route);
    if (d.date.sortKey < row.first.sortKey) row.first = d.date;
    if (d.date.sortKey > row.last.sortKey) row.last = d.date;
    row.descents.push(d);
  }

  for (const row of rows.values()) {
    row.descents.sort(byDateDesc);
    row.routes.sort();
  }

  return [...rows.values()].sort(
    (a, b) => b.count - a.count || a.canyon.name.localeCompare(b.canyon.name),
  );
}

module.exports = { ROLES, FORMAL_ROLES, FLOWS, parseDate, buildLog, rollupCanyons };
