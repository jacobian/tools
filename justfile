# --- canyon log v2 -------------------------------------------------------

# Create an empty canyon database. Fails if one already exists, on purpose.
db-init:
    sqlite3 data/canyons.db < data/schema.sql

# Rebuild data/canyons.db from the v1 Google Sheet. Destructive and repeatable.
migrate-v1:
    bin/migrate-v1

# Build the editor and open it on data/canyons.db. `just serve` watches the
# database, so edits show up on the site without a rebuild.
edit: editor-build
    open -a "$PWD/canyon-editor/build/Canyon Editor.app" --env CANYON_DB="$PWD/data/canyons.db"

# Build canyon-editor/build/Canyon Editor.app. Needs the Swift toolchain that
# ships with the Command Line Tools; no Xcode.
editor-build:
    canyon-editor/build.sh

editor-clean:
    rm -rf canyon-editor/.build "canyon-editor/build"

test:
    node --test

# --- canyon log v1 (retire at cutover) -----------------------------------

fetch-data:
    bin/fetch-canyons

# --- site ----------------------------------------------------------------

serve:
    rm -rf _site/  # workaround for https://github.com/11ty/eleventy/issues/1134
    npx @11ty/eleventy --serve

build: fetch-data
    npx @11ty/eleventy
