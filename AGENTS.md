# tools.jacobian.org

Static site built with [Eleventy](https://11ty.dev). Source → `_site/` (git-ignored).

- **Run**: `just serve` (clears `_site/`, starts dev server)
- **Build**: `just build` (fetches v1 canyon data, builds to `_site/`)
- **Test**: `just test` (`node --test`, over `lib/`)
- **Fetch v1 canyon data**: `just fetch-data`

Node >= 22.5 is required — `_data/canyonlog.js` uses `node:sqlite`. `.node-version`
pins the build host to 24; `package.json` exists only to declare that and to pin
Eleventy.

## Stack

- **Eleventy** with Nunjucks templates (`.njk`) and Liquid for `.html` files
- **Tailwind** via `<script src="https://unpkg.com/@tailwindcss/browser@4">` — no build step
- Styles go in `<style type="text/tailwindcss">` blocks in each page
- Layout: `_includes/index.njk` — supports `containerClass` frontmatter to override `max-w-4xl`
- Data: `_data/*.json` and `_data/*.js` — globally available in templates by
  filename (e.g. `canyons.json` → `{{ canyons }}`, `canyonlog.js` → `{{ canyonlog }}`)
- Passthrough copy is listed **per tool directory** in `eleventy.config.js`, not as
  `**/*.js`: that glob also copied build-time code (`_data/`, `lib/`) into `_site/`,
  and Eleventy offers no way to exclude it — negated globs silently copy nothing.
  A new tool shipping its own JS needs a line there.

## Adding a new tool

Most tools are standalone HTML files (see `pt-tracker/`, `dsf-office-hours/`).

For **data-driven tools** (see `canyons/`):

1. Add a fetch script in `bin/` as a uv inline script (`#!/usr/bin/env -S uv run --script`), writing JSON to `_data/<name>.json`
2. Register it in `justfile` under `fetch-data`
3. Create `<name>/index.njk` with `layout: index.njk` frontmatter; use `{{ <name> }}` to access the data

## UI style discipline

Don't vary font sizes or colors within a page except where the existing file already establishes a pattern. Resist introducing `text-sm`, `text-gray-500`, `text-2xl`, etc. to differentiate elements — keep to the few sizes/colors already in use in each file.

## Canyon Log v2 (`canyons-v2/`) — the live work

Replaces v1. Both are built; v1 is untouched until cutover.

- **Source of truth**: SQLite at `data/canyons.db`, committed. Schema and the
  rating-notation reference are in `data/schema.sql`.
- Three tables: `canyon`, `event`, `descent`. Role, flow and region are plain
  strings; their vocabularies live in `lib/canyonlog.js`, next to the code that
  orders and counts them.
- `descent.date` carries its own precision — `2025-08-16`, `2025-08`,
  `2025-fall` or `2025` — so an entry can say "sometime in August" honestly.
  A `CHECK` enforces the four forms; `parseDate()` derives display and sort keys.
- `descent.route` holds a variant ("Full", "Lower"), so one canyon row covers
  every variant and the by-canyon counts don't fragment.
- `_data/canyonlog.js` queries the DB at build time via `node:sqlite` and hands
  rows to the pure functions in `lib/canyonlog.js` (tested in
  `lib/canyonlog.test.js`). `eleventy.config.js` watches the `.db` — without
  that, editing data leaves `just serve` stale.
- `bin/migrate-v1` rebuilds the DB from the v1 sheet. Destructive and repeatable,
  so its guessing rules can be iterated on. Roles and events are inferred from
  the notes prose and are guesses.

### Editing the data

`canyon-editor/` is a small SwiftUI app over `data/canyons.db` — `just edit`
builds and opens it. Built with SwiftPM and wrapped into an app bundle by
`canyon-editor/build.sh`; no Xcode, no dependencies. It is in `.eleventyignore`.
The role and flow vocabularies are copied from `lib/canyonlog.js` into
`canyon-editor/Sources/CanyonEditor/Models.swift`, so a change to either needs
the other. Hand-editing the DB with `sqlite3` still works; the app assumes it
is the only writer while it's open.

**Cutover** (when v2 is ready): remove `canyons/`, `bin/fetch-canyons`,
`.github/workflows/refresh-canyons.yml`, `_data/canyons.json`,
`_data/canyon_stats.json` and the `fetch-data` recipe; `git mv canyons-v2 canyons`;
update `README.md`.

## Canyon Log v1 (`canyons/`) — being replaced

- Data source: public Google Sheet, fetched via `bin/fetch-canyons`
- Schema: `date, expedition, canyon, link, region, class, flow, notes`
- `bin/fetch-canyons` parses messy dates → `display_date` ("June 2023") + `sort_date` ("2023-06-15"), groups rows by `expedition` into a nested structure, sorts newest-first
- JSON structure: array of `{type: "day trip", ...}` or `{type: "expedition", name, canyons: [...]}`
- Template stripes by outer loop index so expedition rows share a color — v2
  keeps this trick for events
- Note `{{ x if x else '<span>—</span>' | safe }}` in that template is broken: the
  filter binds to the string literal, not the conditional, so the markup renders
  escaped. v2 uses a macro instead. If you add a hover rule, put it on `<tr>`
  directly rather than via `@apply`, to avoid specificity issues
