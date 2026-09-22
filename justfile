# --- canyon log v2 -------------------------------------------------------

# Create an empty canyon database. Fails if one already exists, on purpose.
db-init:
    sqlite3 data/canyons.db < data/schema.sql

# Rebuild data/canyons.db from the v1 Google Sheet. Destructive and repeatable.
migrate-v1:
    bin/migrate-v1

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
