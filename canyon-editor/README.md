# Canyon Editor

A small macOS app for editing `data/canyons.db` — the canyon log v2 database.
Three tables, three panes: descents, canyons, events.

```
just edit           # build (if needed) and open it on data/canyons.db
just editor-build   # build canyon-editor/build/Canyon Editor.app
just editor-clean   # throw away build products
```

`just serve` watches the database, so the site picks up edits without a rebuild.

## How it works

SwiftPM builds a bare executable; `build.sh` wraps it in an app bundle with an
`Info.plist` and an ad-hoc signature. No Xcode and no dependencies — SwiftUI
comes from the Command Line Tools SDK, SQLite from the system library.

- `Database.swift` — a thin wrapper over the SQLite C API.
- `Models.swift` — the three tables, plus the date forms `descent.date` accepts.
  Role and flow vocabularies are copied from `lib/canyonlog.js`; keep them in sync.
- `Store.swift` — the whole database in memory. Every write reloads it.
- `RecordPane.swift` — list, form, search, add and delete, shared by all three panes.

Text columns are non-optional `String`s throughout, with empty meaning "not
filled in"; they're written back as `NULL`. Edits go into a draft and are saved
when you move to another row, or with ⌘S. A row that wouldn't satisfy the
schema won't save, and you can't navigate away from it — the offending field is
already red.

The database path comes from `CANYON_DB`, which `just edit` sets. Opened any
other way, the app remembers the last file you chose.
