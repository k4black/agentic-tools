---
name: anki-connect
description: Use when the user invokes /anki-connect, asks to create or look up Anki flashcards, copy cards between decks, or notices something worth remembering long-term (a concept, gotcha, or vocab from a lesson).
argument-hint: "What to add or look up"
---

# Anki-Connect

Look up and create Anki notes via the [Anki-Connect](https://git.sr.ht/~foosoft/anki-connect) add-on (HTTP API on `http://127.0.0.1:8765`, API v6). Scripts in `./scripts/` (run `--help` for full flags):

| Script | Purpose |
|--------|---------|
| `find_cards.py` | Batch lookup — word-boundary or `--exact`, `-F` multi-field, `--target-deck` classification, `--prefix` article variants, `--detail`, reads stdin |
| `add_card.py`   | Batch create — JSONL on stdin, `clone_from` copies cards between decks |
| `update_card.py` | Partial field patches — JSONL `{"id": <nid>, "fields": {...}}`, other fields/tags untouched |
| `pick_review.py` | N random notes from a deck (default filter `is:due`; `--filter`, `--seed`, `--full`) |
| `anki_connect.py` | HTTP client for ad-hoc calls: `anki_request("<action>", **params)` |

## find_cards.py

```bash
# Word-boundary match in Word field (default): `Mittag` finds `der Mittag`, NOT `Mittagspause`
python ./scripts/find_cards.py Mittag Sommer Klavier

# Lesson dedupe: classify as in-target (=) / elsewhere (+) / missing (✗)
python ./scripts/find_cards.py auf neben Mittag --target-deck "German::My Vocab"

# Canonical German noun entries only: exact + article prefixes
python ./scripts/find_cards.py Klavier Wand --exact --prefix der --prefix die --prefix das
```

## add_card.py

JSONL on stdin, one note per line: `{"fields": {...}, "tags": [...], "deck": "...", "model": "...", "clone_from": <nid>}`. CLI flags give defaults; per-line keys override. `fields` or `clone_from` required.

```bash
# New notes
echo '{"fields":{"Word":"der Tisch","Translation":"стол"}}' | \
  python ./scripts/add_card.py -d "German::My Vocab" -m "My German"

# Clone into another deck (Sound/Image/tags inherited). --allow-duplicate is REQUIRED
# when cloning: Anki's first-field dup check is global and the duplicate is intentional.
echo '{"clone_from": 1442860633303}' | \
  python ./scripts/add_card.py -d "German::My Vocab" -t copied-from-db1 --allow-duplicate
```

Use `--dry-run` to preview large batches.

## update_card.py

```bash
echo '{"id": 1442860633303, "fields": {"Translation": "полдень (~12:00)"}}' | \
  python ./scripts/update_card.py
```

## Common workflows

**Lesson → cards:** extract words → dedupe with `find_cards.py --target-deck` → JSONL: `clone_from` lines for `+`, `fields` lines for `✗` (`=` needs nothing) → `add_card.py --allow-duplicate` → Sound: HyperTTS isn't reachable via Anki-Connect — select new cards in Anki, `Ctrl+Shift+T`.

**Ad-hoc API:** `python -c "from anki_connect import anki_request; print(anki_request('deckNames'))"`

## Card quality rules

The user has 226 leeches. Quality over quantity.

1. **Atomic** — one fact per card; if the answer has "and", split it.
2. **Short, specific front**; **minimal back**.
3. **Visual over prose** — file trees / code blocks / diagrams when the answer is structural.
4. **No trivia** — only things worth remembering long-term.
5. **No auto-tagging** (no `lesson-YYYY-MM-DD` etc.) — tagging is manual and intentional.
6. **German nouns: article in the front field** (`der Sommer`) — gender is part of the word.

## Workflow checklist (before creating any card)

1. **Propose** the cards as an editable JSONL preview. 2. **Wait** for explicit approval — never create without it. 3. **Dedupe** (`find_cards.py --target-deck`). 4. **Create** (`--dry-run` first for large batches). 5. **Confirm** with returned note IDs.

## Personal preferences

### Decks and models

- Active vocab deck: `German::My Vocab` (old DB1 archived as `Archive::Deutsch DB1`). Irregular verbs: `German::Irregular Verbs`.
- **Model `My German`** — fields `Word`, `Translation`, `Sound`, `Image`, `Sentance` (**the typo is the canonical field name**). 4 templates: `German->Russian`, `Russian->German`, `Russian->type German`, `FillSentence` (renders `[word]` brackets in `Sentance` as `[…]` with `{{Translation}}` hint).
- **Model `Umregelmäßige Verben`** — 13 fields: `Infinitiv Singular`, `Translate`, `Präsens 1./2./3. Pers`, `Präsens 1./2./3. Pl`, `Präteritum 3. Pers`, `Perfekt 3. Pers`, `Konjunktiv II`, `Imperativ Singular`, `Imperativ Plural`. 2 templates: `Russian->forms German` (Stammformen), `Infinitiv->all forms` (full Präsens table).

### German verb data (irregular verbs)

- **Canonical CSV**: [viorelsfetea/german-verbs-database](https://github.com/viorelsfetea/german-verbs-database/blob/master/output/verbs.csv) (raw: `https://raw.githubusercontent.com/viorelsfetea/german-verbs-database/master/output/verbs.csv`) — 8k verbs with Präsens ich/du/er, Präteritum, Partizip II, Konjunktiv II, Imperativ Sg/Pl, Hilfsverb.
  ```bash
  curl -sL <raw-url> -o /tmp/verbs.csv
  python3 -c "import csv; print([r for r in csv.DictReader(open('/tmp/verbs.csv')) if r['Infinitive']=='gehen'][0])"
  ```
- **Never hand-author CSV-sourced forms** (Präsens singular, Präteritum, Konjunktiv II, Imperativ) — strong-verb stem changes are not derivable. Re-import from the CSV.
- **Rule-derived plurals** (not in CSV; deterministic — plurals never carry the singular vowel change): `wir = base [+ separable prefix]`; `ihr = stem + ('et' if stem ends t/d else 't') [+ prefix]`; `sie/Sie = wir`. Separable detection: space in the CSV's `Präsens_ich`.
- **Hardcoded**: `sein` (missing from CSV).
- **Lookup normalization** (lookup only — stored fields unchanged): strip `(mit D.)` parentheticals, strip leading `sich `, fix the `umzihen→umziehen` typo.

### Sentence/cloze format (`Sentance` field)

- **Bracket notation only**: `Ich lege das Buch [auf] den Tisch.` Never Anki `{{c1::}}` cloze — `My German` is a Standard model; keep the field clean text (the template's bracket-regex JS does the rendering).
- Separable verbs in split position: bracket each part — `Der Bus [kommt] um neun Uhr [an].`
- One bracket-group per card unless grammar demands more.

### Sentence design rules

1. **Natural, real-world** sentences — no textbook filler.
2. **Support words stay A1/A2** — only the bracketed target should be new.
3. **Vary forms across the deck**: tenses (Präsens all persons, Perfekt, Präteritum, Plusquamperfekt, Futur I), mood (Indikativ, Konjunktiv II both forms, Imperativ du/ihr/Sie), voice (Aktiv, Vorgangs-/Zustandspassiv), modals + Infinitiv, verb structure (separable split/zusammen, untrennbar, reflexive), sentence types (Aussage, W-/Ja-Nein-Frage, Imperativ, Nebensatz weil/dass/wenn/sobald/während/obwohl, Relativsatz), cases (Nom/Akk/Dat incl. Wechselpräpositionen, Genitiv wegen/während/trotz), adjectives (predicative, declined strong/mixed/weak, Komparativ, Superlativ).

### Verification habit

After bulk sentence updates: morphology-aware match check (strip article, normalize umlauts, handle `ge-` and separable prefixes), random-sample ~20 cards manually; strong-verb irregulars (`wissen→weiß`, `nehmen→nimm`) never match algorithmically — eyeball those.

## Troubleshooting

Requires Anki desktop running with Anki-Connect (AnkiWeb [2055492159](https://ankiweb.net/shared/info/2055492159)); `http://127.0.0.1:8765` should print `Anki-Connect`. On macOS disable App Nap so background Anki keeps responding:

```bash
defaults write net.ankiweb.dtop NSAppSleepDisabled -bool true
defaults write net.ichi2.anki NSAppSleepDisabled -bool true
defaults write org.qt-project.Qt.QtWebEngineCore NSAppSleepDisabled -bool true
```
