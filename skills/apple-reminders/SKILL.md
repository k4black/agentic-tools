---
name: apple-reminders
description: Use when the user wants to add, view, complete, or organize items in Apple Reminders, or says "remind me", "add to my list", "todo".
---

# Apple Reminders

Add, view, complete, and organize Apple Reminders. Pure AppleScript via `osascript`, no external deps (macOS + Reminders app). Adapted from [densign01/reminders-skill](https://github.com/densign01/reminders-skill).

## Read

```bash
# All list names
osascript -e 'tell application "Reminders" to get name of every list'

# Open items on a list (with due dates)
osascript -e 'tell application "Reminders"
    set out to {}
    repeat with r in (reminders in list "LIST_NAME" whose completed is false)
        set n to name of r
        if due date of r is not missing value then set n to n & " (due: " & (due date of r as string) & ")"
        set end of out to n
    end repeat
    return out
end tell'
```

## Add items

1. **Pick the list** — if unspecified, ask, showing available lists.
2. **Dedupe** — fetch open items (query above); case-insensitive partial match.
3. **Parse** — bullet/comma items, due dates ("tomorrow", "in 3 days", "Jan 15"), notes (after a dash or in parens).
4. **Confirm the plan before mutating**:

   ```
   ## Adding to [List Name] (X new items)
   **Will add:** - Item 1  - Item 2 (due: tomorrow)
   **Already on list (skipping):** - ~~Item 3~~
   ```

5. **Add** (batch multiple items in one call):

```bash
osascript <<'EOF'
tell application "Reminders"
    set targetList to list "LIST_NAME"
    make new reminder in targetList with properties {name:"Item 1"}
    make new reminder in targetList with properties {name:"Item 2", due date:(current date) + (1 * days)}
end tell
EOF
```

## Complete an item

```bash
osascript -e 'tell application "Reminders"
    repeat with r in (reminders in list "LIST_NAME" whose completed is false)
        if name of r contains "SEARCH_TERM" then
            set completed of r to true
            return "Completed: " & name of r
        end if
    end repeat
    return "Not found"
end tell'
```

## Create a list

```bash
osascript -e 'tell application "Reminders" to make new list with properties {name:"LIST_NAME"}'
```

## Date parsing

| Input | AppleScript |
|-------|-------------|
| today / tomorrow / next week | `(current date)` / `+ (1 * days)` / `+ (7 * days)` |
| in X days | `(current date) + (X * days)` |
| Monday, Tuesday, … | days until that weekday |
| Jan 15, March 3, … | construct a date object |

Specific time: `set hours of dueDate to 14` / `set minutes of dueDate to 0`.

## Rules

- Always confirm the add-plan before mutating (show adds + skips).
- Due dates optional; dedupe is case-insensitive partial match.
- Referenced list doesn't exist → offer to create it, never fail silently.
