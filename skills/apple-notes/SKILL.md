---
name: apple-notes
description: Use when the user wants to read, search, rename, move, or reorganize Apple Notes — especially notes containing hyperlinks, where naive AppleScript/MCP body operations silently strip URLs.
---

# Apple Notes

Read and manipulate Apple Notes safely — the naive paths (AppleScript `body`, MCP `update-note`, `set name`) silently destroy URLs, prepend instead of replace, or operate on stale IDs. Scripts in `./scripts/`.

## Critical gotchas

1. **`body` has no link URLs.** AppleScript `body` renders links as `<u>Title</u>` — the URLs live in CoreData, unreachable via AppleScript. Any read-modify-write of a linked note loses every URL. Notes with links MUST go through markdown export (below) or MCP `get-note-markdown` (preferred when available).
2. **The title is a styled `<div>`, not `<h1>`**: `<div><b><span style="font-size: 24px">Title</span></b></div>`. Logic that replaces `<h1>` silently falls through and *prepends* a second title, corrupting the note.
3. **`set name` only changes the sidebar preview** — the real title renders from the body's first line. Rename by editing the title `<div>` in the body.
4. **MCP `move-note` creates a NEW note id**; the old id lands in Recently Deleted. Re-fetch by search/list after every move.
5. **MCP `update-note` requires full `newContent`** — no title-only updates; risks formatting loss. Use the AppleScript body-edit pattern instead.
6. **`search-notes` includes trash** — verify folder + id before operating; stale post-move ids live there.

## Workflows

### Edit a note that contains links

1. Export: `./scripts/apple_notes_export.sh <note_id> <output_dir> [filename]` (or MCP `get-note-markdown`).
2. Modify the `.md` (links appear as `++[Title](URL)++`).
3. Re-import: `python3 ./scripts/apple_notes_import.py <md_file> --note-id <id>` (new note: omit `--note-id`, pass `--folder <name>`).

### Rename a note (title only, body preserved)

Only for notes WITHOUT links (otherwise export→import). Get `body` via osascript, replace the title `<div>` (match the styled span, never `<h1>`), write back via a temp file to dodge shell escaping:

```python
import subprocess, tempfile, os
body = subprocess.run(['osascript', '-e',
    f'tell application "Notes" to get body of note id "{note_id}"'],
    capture_output=True, text=True).stdout.strip()
# ...replace the title <div> in body...
with tempfile.NamedTemporaryFile(mode='w', suffix='.html', delete=False, encoding='utf-8') as f:
    f.write(body); tmp = f.name
subprocess.run(['osascript', '-e', f'''
set fRef to open for access POSIX file "{tmp}"
set newBody to read fRef as «class utf8»
close access fRef
tell application "Notes" to set body of note id "{note_id}" to newBody'''])
os.unlink(tmp)
```

### Reorganize (move + rename + preserve links)

Export markdown (if links) → MCP `move-note` → **re-fetch the new id** → rename via the pattern above → re-import the markdown.

## Scripts

- **`apple_notes_export.sh`** — GUI-scripts File → Export as → Markdown; requires Accessibility permission for the terminal (System Settings → Privacy & Security). Output: `<output_dir>/<filename>/<filename>.md`; links come out as `++[Title](URL)++`; consecutive duplicate link lines are deduped.
- **`apple_notes_import.py`** — converts `[Title](URL)`/`++[Title](URL)++` to `<a href>`, `# headers` to the styled title `<div>`, `**bold**` to `<b>`; Apple re-renders `<a>` as clickable links. Python 3 stdlib only.

## Codex vs Claude Code

The `apple-notes` MCP (Claude Code) provides `get-note-markdown`, `move-note`, `search-notes` — prefer them; faster, no GUI scripting. Under Codex (no MCP): bundled scripts + raw AppleScript.
