/**
 * Canyon log data for the canyons-v2 templates, read straight out of
 * data/canyons.db at build time.
 *
 * Deliberately not called "canyons" -- that name belongs to v1's
 * _data/canyons.json until cutover.
 *
 * Needs node:sqlite, so Node >= 22.5 (stable in 24). .node-version pins the
 * build host; see the deploy note in README/CLAUDE.md if a build fails here.
 */

const path = require("node:path");
const { DatabaseSync } = require("node:sqlite");

const { buildLog, rollupCanyons, FORMAL_ROLES } = require("../lib/canyonlog.js");

const DB = path.join(__dirname, "..", "data", "canyons.db");

const QUERY = `
  SELECT d.id, d.date, d.route, d.role, d.flow, d.conditions, d.partners, d.notes,
         c.id     AS canyon_id,
         c.name   AS canyon_name,
         c.region AS canyon_region,
         c.aka, c.aca_rating, c.ffme_rating, c.raps, c.longest_rap_ft,
         c.best_season, c.permits, c.coordinates, c.url,
         c.notes  AS canyon_notes,
         e.id     AS event_id,
         e.name   AS event_name,
         e.start_date, e.end_date,
         e.notes  AS event_notes
    FROM descent d
    JOIN canyon c ON c.id = d.canyon_id
    LEFT JOIN event e ON e.id = d.event_id
`;

/** One flat SQL row -> a descent with its canyon and event nested. */
function shape(row) {
  return {
    id: row.id,
    date: row.date,
    route: row.route,
    role: row.role,
    flow: row.flow,
    conditions: row.conditions,
    partners: row.partners,
    notes: row.notes,
    canyon: {
      id: row.canyon_id,
      name: row.canyon_name,
      region: row.canyon_region,
      aka: row.aka,
      aca_rating: row.aca_rating,
      ffme_rating: row.ffme_rating,
      raps: row.raps,
      longest_rap_ft: row.longest_rap_ft,
      best_season: row.best_season,
      permits: row.permits,
      coordinates: row.coordinates,
      url: row.url,
      notes: row.canyon_notes,
    },
    event: row.event_id
      ? {
          id: row.event_id,
          name: row.event_name,
          start_date: row.start_date,
          end_date: row.end_date,
          notes: row.event_notes,
        }
      : null,
  };
}

function summarise(descents, byCanyon) {
  const byRole = {};
  for (const d of descents) byRole[d.role] = (byRole[d.role] || 0) + 1;

  return {
    descents: descents.length,
    canyons: byCanyon.length,
    formal: descents.filter((d) => FORMAL_ROLES.has(d.role)).length,
    repeats: byCanyon.filter((c) => c.count > 1).length,
    byRole,
  };
}

module.exports = function () {
  const db = new DatabaseSync(DB, { readOnly: true });
  let descents;
  try {
    descents = db.prepare(QUERY).all().map(shape);
  } finally {
    db.close();
  }

  const byCanyon = rollupCanyons(descents);
  return {
    log: buildLog(descents),
    byCanyon,
    stats: summarise(descents, byCanyon),
  };
};
