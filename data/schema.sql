-- Canyon log v2.
--
-- Three tables. Vocabularies for role and flow live in lib/canyonlog.js, next to
-- the code that orders and counts them, rather than as lookup tables here -- this
-- keeps the database trivially hand-editable.

PRAGMA foreign_keys = ON;

-- A canyon: a place, not a trip. Entered by hand; most columns start NULL.
--
-- Rating notation, for reference when filling these in:
--
--   aca_rating   American Canyoneering Association, the scheme that matters for
--                US canyons: technical 1-4, water A-C, time I-VI, e.g. "3C IV".
--                Water rating takes subgrades C1-C4 for current strength, so
--                "3C3 IV" is valid and not a typo. Extra risk (R, PG, X, XX)
--                trails the whole thing: "3C IV R".
--
--   ffme_rating  Federation Francaise de la Montagne et de l'Escalade, used for
--                European canyons: vertical v1-v7, aquatic a1-a7, commitment
--                I-VI, e.g. "v4a4 III".
--
-- Fill in whichever applies; a canyon may have both or neither.
CREATE TABLE canyon (
    id              INTEGER PRIMARY KEY,
    name            TEXT NOT NULL,
    region          TEXT NOT NULL,
    aka             TEXT,           -- alternate names
    aca_rating      TEXT,
    ffme_rating     TEXT,
    raps            TEXT,           -- a range in practice: "4-7"
    longest_rap_ft  INTEGER,
    best_season     TEXT,
    permits         TEXT,
    coordinates     TEXT,           -- "45.6432, -122.0926"
    url             TEXT,
    notes           TEXT            -- about the canyon, not about any descent
);

-- A named trip containing several descents: an expedition (Escalante, Grand
-- Canyon) or a recurring gathering (PNW Rondy, a Mazamas campout). Non-canyon
-- days of an expedition are described in notes rather than recorded as rows.
CREATE TABLE event (
    id          INTEGER PRIMARY KEY,
    name        TEXT NOT NULL,
    start_date  TEXT CHECK (start_date IS NULL OR start_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
    end_date    TEXT CHECK (end_date   IS NULL OR end_date   GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
    notes       TEXT
);

-- One descent of one canyon: a log entry.
--
-- date carries its own precision, so an entry can honestly say "sometime in
-- October 2024" instead of inventing a day. Four accepted forms:
--
--   2025-08-16   an exact day
--   2025-08      some day in August 2025
--   2025-fall    sometime that season (spring, summer, fall, winter)
--   2025         sometime that year
--
-- GLOB has no alternation, so each season needs its own clause below.
CREATE TABLE descent (
    id          INTEGER PRIMARY KEY,
    canyon_id   INTEGER NOT NULL REFERENCES canyon(id),
    event_id    INTEGER REFERENCES event(id),   -- NULL when not part of an event
    date        TEXT NOT NULL CHECK (
                       date GLOB '[0-9][0-9][0-9][0-9]'
                    OR date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]'
                    OR date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
                    OR date GLOB '[0-9][0-9][0-9][0-9]-spring'
                    OR date GLOB '[0-9][0-9][0-9][0-9]-summer'
                    OR date GLOB '[0-9][0-9][0-9][0-9]-fall'
                    OR date GLOB '[0-9][0-9][0-9][0-9]-winter'
                ),
    route       TEXT,       -- variant descended: "Full", "Lower", "Middle"
    role        TEXT NOT NULL,
    flow        TEXT,
    conditions  TEXT,       -- free text: "ice!", "potholes full", "bailed"
    partners    TEXT,
    notes       TEXT
);

CREATE INDEX descent_canyon ON descent(canyon_id);
CREATE INDEX descent_date   ON descent(date);
