const test = require("node:test");
const assert = require("node:assert");

const { parseDate, buildLog, rollupCanyons } = require("./canyonlog.js");

// --- dates ---------------------------------------------------------------

test("parseDate reads an exact day", () => {
  assert.deepEqual(parseDate("2025-08-16"), {
    precision: "day", display: "16 August 2025", sortKey: "2025-08-16",
  });
});

test("parseDate reads a month", () => {
  assert.deepEqual(parseDate("2025-08"), {
    precision: "month", display: "August 2025", sortKey: "2025-08-01",
  });
});

test("parseDate reads a season", () => {
  assert.deepEqual(parseDate("2025-fall"), {
    precision: "season", display: "Fall 2025", sortKey: "2025-09-01",
  });
  assert.equal(parseDate("2025-winter").sortKey, "2025-12-01");
});

test("parseDate reads a bare year", () => {
  assert.deepEqual(parseDate("2025"), {
    precision: "year", display: "2025", sortKey: "2025-01-01",
  });
});

test("parseDate rejects anything else", () => {
  for (const bad of ["", "2025-13-01", "August 2025", "25-08-16", null]) {
    assert.throws(() => parseDate(bad), /date/i, `should reject ${bad}`);
  }
});

// --- log ordering --------------------------------------------------------

const descent = (date, over = {}) => ({
  id: over.id ?? date,
  date,
  role: over.role ?? "participant",
  route: over.route ?? null,
  canyon: over.canyon ?? { id: 1, name: "Duncan" },
  event: over.event ?? null,
});

test("buildLog puts newest first", () => {
  const log = buildLog([descent("2024-06-01"), descent("2026-01-15"), descent("2025-03-02")]);
  assert.deepEqual(log.map((e) => e.date.sortKey), ["2026-01-15", "2025-03-02", "2024-06-01"]);
});

test("buildLog sorts a fuzzy date to the start of its period, after the precise days", () => {
  // "sometime in August" belongs with August, not before it or after July.
  const log = buildLog([
    descent("2025-08-20"), descent("2025-08"), descent("2025-08-05"), descent("2025-07-30"),
  ]);
  assert.deepEqual(log.map((e) => e.date.sortKey),
    ["2025-08-20", "2025-08-05", "2025-08-01", "2025-07-30"]);
});

test("buildLog breaks a sortKey tie by precision, precise first", () => {
  const log = buildLog([descent("2025-08"), descent("2025-08-01")]);
  assert.deepEqual(log.map((e) => e.date.precision), ["day", "month"]);
});

test("buildLog groups descents under their event", () => {
  const rondy = { id: 7, name: "PNW Rondy 2025" };
  const log = buildLog([
    descent("2025-08-14", { id: "a", event: rondy }),
    descent("2025-08-16", { id: "b", event: rondy }),
    descent("2025-07-01", { id: "c" }),
  ]);
  assert.equal(log.length, 2);
  assert.equal(log[0].type, "event");
  assert.equal(log[0].name, "PNW Rondy 2025");
  assert.deepEqual(log[0].descents.map((d) => d.id), ["b", "a"]);
  assert.equal(log[1].type, "descent");
});

test("buildLog positions an event by its newest descent", () => {
  const event = { id: 7, name: "Escalante" };
  const log = buildLog([
    descent("2025-05-01", { id: "a", event }),
    descent("2025-05-09", { id: "b", event }),
    descent("2025-05-05", { id: "solo" }),
  ]);
  assert.deepEqual(log.map((e) => e.name ?? e.id), ["Escalante", "solo"]);
});

test("buildLog keeps same-named events in different years apart", () => {
  const log = buildLog([
    descent("2024-07-25", { id: "a", event: { id: 1, name: "PNW Rondy 2024" } }),
    descent("2025-08-14", { id: "b", event: { id: 2, name: "PNW Rondy 2025" } }),
  ]);
  assert.equal(log.length, 2);
});

// --- per-canyon rollup ---------------------------------------------------

test("rollupCanyons counts descents and formal leadership separately", () => {
  const pin = { id: 3, name: "Pin" };
  const rows = rollupCanyons([
    descent("2026-08-08", { canyon: pin, role: "lead guide" }),
    descent("2026-08-16", { canyon: pin, role: "lead guide" }),
    descent("2026-09-12", { canyon: pin, role: "assistant guide" }),
    descent("2025-01-01", { canyon: pin, role: "participant" }),
    descent("2024-01-01", { canyon: pin, role: "student" }),
  ]);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].count, 5);
  assert.equal(rows[0].formalCount, 3); // lead + assistant guide, not participant/student
});

test("rollupCanyons reports the span of visits", () => {
  const rows = rollupCanyons([
    descent("2024-06-01"), descent("2026-01-15"), descent("2025-03-02"),
  ]);
  assert.equal(rows[0].first.display, "1 June 2024");
  assert.equal(rows[0].last.display, "15 January 2026");
});

test("rollupCanyons collects the routes descended, without duplicates", () => {
  const eagle = { id: 9, name: "Eagle" };
  const rows = rollupCanyons([
    descent("2024-07", { canyon: eagle, route: "Full" }),
    descent("2024-08", { canyon: eagle, route: "Lower" }),
    descent("2026-06-19", { canyon: eagle, route: "Lower" }),
    descent("2026-09-11", { canyon: eagle, route: null }),
  ]);
  assert.deepEqual(rows[0].routes, ["Full", "Lower"]);
});

test("rollupCanyons orders by descent count, then name", () => {
  const rows = rollupCanyons([
    descent("2025-01-01", { canyon: { id: 1, name: "Zebra" } }),
    descent("2025-01-02", { canyon: { id: 2, name: "Alpha" } }),
    descent("2025-01-03", { canyon: { id: 2, name: "Alpha" } }),
    descent("2025-01-04", { canyon: { id: 3, name: "Beta" } }),
  ]);
  assert.deepEqual(rows.map((r) => [r.canyon.name, r.count]),
    [["Alpha", 2], ["Beta", 1], ["Zebra", 1]]);
});

test("rollupCanyons sorts each canyon's own descents newest first", () => {
  const rows = rollupCanyons([
    descent("2024-06-01", { id: "old" }),
    descent("2026-01-15", { id: "new" }),
    descent("2025-03-02", { id: "mid" }),
  ]);
  assert.deepEqual(rows[0].descents.map((d) => d.id), ["new", "mid", "old"]);
});
