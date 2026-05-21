# Immich Triage

A browser-based tool for winnowing a large Immich photo album down to a small set of keepers.

## Current state

`index.html` is a fully client-side tool (no build-time data, no server). It:

- Shows a login form asking for an Immich instance URL and API key
- Validates credentials against the API before saving
- Persists credentials to `localStorage` so the session survives page reloads
- Fetches and displays all albums as a grid (sorted by most recently updated)
- Loads album thumbnails via authenticated `fetch()` + blob URLs (plain `<img src>` won't work because Immich thumbnails require the `x-api-key` header)

## What's next

The actual triage UI: pick an album, page through its photos one at a time (or in a grid), and mark each as keep/delete/skip. Likely workflow:

1. Click an album → enter triage view
2. Show photos one at a time (or small grid); keyboard shortcuts to keep/delete/skip
3. Review selections before committing
4. Execute deletions via the Immich API

## API key permissions needed

- `album.read` — list albums (current)
- `asset.read` — fetch thumbnails (current)
- `asset.delete` — delete photos (future)
- `album.update` — remove photos from album without deleting (future)

Create the key with all four scopes up front.

## CORS situation

Immich doesn't set CORS headers, and Synology's built-in reverse proxy can't add response headers (only `proxy_set_header`, not `add_header`). Unresolved as of this writing. Options explored:

- **Caddy in Docker** — cleanest; needs ports 80/443 freed from Synology first
- **Boot-script nginx patching** — fragile across DSM updates
- See conversation for details

Headers needed (permissive, since auth comes from Tailscale):

```
Access-Control-Allow-Origin: *
Access-Control-Allow-Headers: *
Access-Control-Allow-Methods: *
```
