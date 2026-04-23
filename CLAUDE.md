# tools.jacobian.org

Static site built with [Eleventy](https://11ty.dev). Source → `_site/` (git-ignored).

- **Run**: `just serve` (fetches data, clears `_site/`, starts dev server)
- **Build**: `just build` (fetches data, builds to `_site/`)
- **Fetch data only**: `just fetch-data`

## Stack

- **Eleventy** with Nunjucks templates (`.njk`) and Liquid for `.html` files
- **Tailwind** via `<script src="https://unpkg.com/@tailwindcss/browser@4">` — no build step
- Styles go in `<style type="text/tailwindcss">` blocks in each page
- Layout: `_includes/index.njk` — supports `containerClass` frontmatter to override `max-w-4xl`
- Data: `_data/*.json` — globally available in templates by filename (e.g. `canyons.json` → `{{ canyons }}`)

## Adding a new tool

Most tools are standalone HTML files (see `pt-tracker/`, `dsf-office-hours/`).

For **data-driven tools** (see `canyons/`):

1. Add a fetch script in `bin/` as a uv inline script (`#!/usr/bin/env -S uv run --script`), writing JSON to `_data/<name>.json`
2. Register it in `justfile` under `fetch-data`
3. Create `<name>/index.njk` with `layout: index.njk` frontmatter; use `{{ <name> }}` to access the data

## Canyon Log (`canyons/`)

- Data source: public Google Sheet, fetched via `bin/fetch-canyons`
- Schema: `date, expedition, canyon, region, class, flow, notes`
- `bin/fetch-canyons` parses messy dates → `display_date` ("June 2023") + `sort_date` ("2023-06-15"), groups rows by `expedition` into a nested structure, sorts newest-first
- JSON structure: array of `{type: "day trip", ...}` or `{type: "expedition", name, canyons: [...]}`
- Template stripes by outer loop index so expedition rows share a color; `hover:bg-red-50` goes on `<tr>` directly (not via `@apply`) to avoid specificity issues
