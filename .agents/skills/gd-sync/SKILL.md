---
name: gd-sync
description: Push, pull, or synchronize a local directory against a configured Google Drive folder with gog CLI. Use when the user asks to initialize, upload, download, or synchronize a folder governed by gd-sync.yml, including ignore rules, Google-native HTML, pointer, or export handling, and last-sync tracking.
---

# Google Drive Sync

Reconcile a local folder with Google Drive. The default `sync` workflow compares each local file with its remote counterpart: newer remote files are pulled over local files, and newer local files are pushed over remote files. `push` and `pull` remain available as explicitly one-way operations. Sync never deletes remote-only or local-only files.

## Default invocation behavior

- When the user invokes this skill without an explicit direction or mode (for example, `$gd-sync` or `$gd-sync 를 실행해`), treat it as an explicit request for a full bidirectional `sync`.
- Execute requested `sync`, `pull`, or `push` operations exactly once. Do not perform an additional inspection or confirmation before the requested operation.
- Use `push`, `pull`, or `init` only when the user explicitly requests that mode. Otherwise default to `sync`.

### Freshness guard

- For an existing file whose contents differ, compare the local filesystem modification time with the remote Drive `modifiedTime`.
- Sync pulls only when the remote file is strictly newer than the local file, and pushes only when the local file is strictly newer than the remote file.
- One-way pull overwrites only when the remote file is strictly newer than the local file. One-way push uploads only when the local file is strictly newer than the remote file.
- If timestamps are equal or unavailable, the existing file is skipped conservatively.
- An exact MD5 match is always skipped as already synchronized. New files are created normally.
- Equal timestamps and missing remote timestamps are treated conservatively as conflicts so an existing file is never overwritten without a freshness signal. `last_sync_at` is informational and is not used as a global freshness cutoff.
- The guard is implemented by `scripts/gd_sync.py`; invoking `gog drive sync push` directly bypasses it.

## Result reporting

- After a successful push or pull, include a brief file list in the result.
- List only files actually created or updated/overwritten by that operation; do not list skipped or ignored files.
- Write paths relative to the local root as plain text, without Markdown links, backticks, or other clickable formatting. Include folders only when useful to explain a newly created directory, not in the file list.
- If more than 30 files changed, list the first 30 paths and state how many additional files changed. If no files changed, state `Files changed: none`.

## Sync workflow

The default command is `sync`. Run it directly:

```powershell
python <skill-dir>/scripts/gd_sync.py --root <local-root>
```

The remote phase runs first. This ensures that a remote-newer file is written locally before the upload phase stages files, while a local-newer file remains eligible for upload.

## Push workflow

1. Identify the local root from the user's request. Use the current working directory only when the intended root is unambiguous.
2. Inspect `gd-sync.yml`. Require a non-placeholder `drive_folder_id`. Preserve `gd-sync.yml` in the ignore list.
3. If `gog` is missing or authentication is not configured, relay the script's setup guidance and stop. A keyring lock or filesystem permission error is an execution-environment problem, not proof that an account is missing. In a sandbox, rerun the authentication check with permission to access the user's existing gog keyring before diagnosing authentication.
4. If `gd-sync.yml` is missing, the script creates it and stops. Ask the user to fill `drive_folder_id`, or fill it from a Drive folder URL/ID explicitly supplied by the user.
5. Execute the push immediately:

   ```powershell
   python <skill-dir>/scripts/gd_sync.py --root <local-root> --direction push
   ```

6. The script queries remote `modifiedTime` values before staging the push. Files reported as `skip_file ... remote is newer or same age` or `remote modifiedTime unavailable` are not passed to `gog drive sync push`.
7. Report whether the push completed, the new `last_sync_at` value, and a brief plain-text list of files actually created or updated.
8. Exclude `.gdrive.html` files only when they contain gd-sync's generator marker, and exclude pointer files only when they contain gd-sync's warning plus a `doc_id`. Do not exclude user-authored ordinary HTML, including manually created `.gdrive.html` files without that marker.

## Pull workflow

1. Inspect `gd-sync.yml` and require a non-placeholder `drive_folder_id`.
2. Execute pull immediately:

   ```powershell
   python <skill-dir>/scripts/gd_sync.py --root <local-root> --direction pull
   ```

3. For existing files, the script compares the remote `modifiedTime` with the local filesystem modification time; local-newer, equal-time, and missing-remote-time files are skipped. Pull never deletes local-only files.
4. Report created, updated, skipped, and ignored counts plus the new `last_sync_at` value and a brief plain-text list of files actually created or updated.
5. Treat same-name transformed remote paths, unsafe names, and file/folder type conflicts as errors instead of guessing.
6. Handle Google-native documents according to `google_native`:
   - `html` (default): create `original-name.gdrive.html` for Docs, Sheets, Slides, Forms, Drawings, and other Google-native files. The cross-platform HTML opens the current `webViewLink` and needs only a browser.
   - `pointer`: create Drive for desktop-compatible `.gdoc`, `.gsheet`, `.gslides`, `.gdraw`, `.gform`, and related JSON pointer files containing `doc_id`, `resource_key`, and account email. Unknown Google-native types fall back to HTML.
   - `export`: export Docs to DOCX, Sheets to XLSX, Slides to PPTX, and Drawings to PNG. Fall back to `original-name.gdrive.html` for Forms and other non-exportable Google-native types.
7. Link files use UTF-8 HTML, a no-JavaScript meta refresh, an escaped clickable fallback URL, and the escaped original document name.

## Configuration

Use this schema in `<local-root>/gd-sync.yml`:

```yaml
drive_folder_id: "Google Drive folder ID"
google_native: "html"  # html | pointer | export
last_sync_at: null
ignore:
  - "gd-sync.yml"
  - ".agents/"
  - ".codex/"
  - ".claude/"
  - ".git/"
  - "*.tmp"
```

- Use `html` when collaborators should open the live Drive document on Windows, macOS, or Linux with only a browser. Use `pointer` when Drive for desktop pointer compatibility is required. Use `export` when editable offline Office copies are preferred. Legacy `link` values are read as `html`.
- Interpret ignore entries as path globs relative to the local root.
- Apply ignore entries in both push and pull directions.
- Treat a trailing `/` as a directory and all of its descendants.
- Always ignore `gd-sync.yml` and the agent configuration directories `.agents/`, `.codex/`, and `.claude/`, even if a user removes them from the list.
- Update `last_sync_at` only after a successful push or pull.
- Refuse local symbolic links instead of silently following them.

## Authentication

The script detects a missing CLI or base configuration. Run `gog auth list --check` before diagnosing an authentication problem. If inspection in a sandbox reports `missing --account`, a keyring lock, a read-only filesystem, or a permission error, state that authentication could not be inspected and retry with access to the existing keyring. Do not tell the user to reconfigure authentication based on those errors alone.

Only if the unrestricted check confirms missing or invalid credentials or tokens during push or pull, guide the user through:

```powershell
gog auth credentials set <oauth-client.json>
gog auth add <email>
gog auth list --check
```

Allow the user's configured keyring to prompt interactively. Never request, print, or persist the keyring password in project files or command history.
