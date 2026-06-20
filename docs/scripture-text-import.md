# Scripture text import — scope and limitations

This document records what the **v1 USFM import** does today, what it deliberately skips, and known quality gaps. Use it when extending `BibleReader.ScriptureText`, the parser, or chapter rendering so we do not rediscover the same boundaries.

**Related code:** `lib/biblereader/scripture_text/`, `lib/mix/tasks/scripture.import.ex`, `lib/biblereader_web/components/scripture_components.ex`.

---

## Architecture (intentional)

| Layer | Role |
|-------|------|
| **USFM on disk** | Extracted files in `priv/scripture/usfm/deuelbbk/` (gitignored). Optional one-time `deuelbbk_usfm.zip` in project root to populate that folder; safe to delete the zip after extract. |
| **PostgreSQL** | Normalized runtime model: `chapter_documents`, `bible_verses`, `bible_footnotes` |
| **LiveView** | Reads JSON from DB only; never parses USFM at request time |

User notes, read logs, and highlights are **overlays** on catalog chapters — they must not edit USFM or stored translation rows in place.

---

## Import pipeline (today)

- **Command:** `mix scripture.import deuelbbk`
- **Source:** Elberfelder USFM under `priv/scripture/usfm/deuelbbk/*.usfm`. First-time setup can unzip `deuelbbk_usfm.zip` from the project root (not committed; copyrighted); **the zip can be deleted** once `.extracted` exists and the 66 book files are present.
- **Translations:** Only `deuelbbk` is implemented; other codes return `{:error, {:unsupported_translation, _}}`.
- **Book matching:** Filename / `\id` code must match `books.code` in the scripture catalog. Known alias: **JOL → JOE**. Unknown books are skipped with a warning. **Joel** uses **4 chapters** in this catalog (matches Elberfelder USFM; some English Bibles use 3).
- **Re-import:** Per-chapter replace (delete footnotes/verses/document, then insert). Safe to re-run after parser fixes.
- **Not in `mix setup`:** Import is slow (~1 min) and optional; chapter pages work without text.

---

## USFM markers — supported in v1

| Marker | Stored as |
|--------|-----------|
| `\c` | Chapter boundary |
| `\p` | Paragraph block (`kind: "p"`) |
| `\v` | Verse number + inline text; verse index row |
| `\f` … `\f*` with `\fr`, `\ft` | `footnote_ref` in content + `bible_footnotes.body` (plain string) |

**Skipped entirely (no block in output):** `\id`, `\toc*`, `\mt*`, `\s`, `\s1`–`\s4`.

**Flattened to plain text (markup lost):** `\em`, `\add`, `\nd`, `\+em`, `\+add`, `\+nd`. Closing markers are no-ops. Adjacent text nodes are merged with a space when a paragraph block is finalized (and in verse `content_json`), which usually preserves word boundaries around `\add`; edge cases may still read awkwardly (e.g. “r Bestimmung von” in Genesis 1:14).

**Footnote bodies:** Text and character styles between `\ft` and `\f*` (including nested `\+add`) belong in `bible_footnotes.body`, not in the main verse flow. The parser routes those tokens into the active footnote field.

---

## USFM / content — not implemented (future)

Track these when prioritising parser/renderer work:

- [ ] **Headings in flow** — `\s`, `\s1`–`\s4`, `\ms`, etc.
- [ ] **Poetry / layout** — `\q`, `\q1`, `\q2`, `\m`, `\b`, `\li`
- [ ] **Cross-references** — `\x` … `\x*`
- [ ] **Character styles in AST** — preserve `\em`, `\add`, `\nd`, words of Jesus, small caps (not flatten)
- [ ] **Rich footnote bodies** — structured `FootnoteNode[]` (`originRef`, `quote`, `alternateTranslation`) instead of one string
- [ ] **Strong’s / morphology** — `\w`, `\wh`, etc.
- [ ] **Paragraph spans** — explicit block boundaries when poetry crosses verses
- [ ] **Other USFM footnote parts** — `\fq`, `\fqa`, `\fk`, `\fl`, etc. (only `\fr` + `\ft` merged today)
- [ ] **Additional import formats** — USX, OSIS, SWORD (import-only), per product licensing
- [ ] **Additional translations** — user preference; not only hard-coded `deuelbbk`

---

## Database / content model limits

| Topic | v1 behavior | Future |
|-------|-------------|--------|
| **Verse `content_json`** | `text` + `footnote_ref` nodes only | Spans, emphasis, cross-ref refs |
| **Footnote `body`** | Single plain string (`\fr` + `\ft`, markup stripped) | `body_json` or structured nodes |
| **Footnote link id** | `ref_id` (parser UUID), not DB primary key | Stable if re-import strategy changes |
| **`plain_text`** | Text nodes only; footnote text excluded. May be **empty** for verse rows that only have a verse marker | Required for search/copy; backfill rules on import |
| **`display_number`** | Per-chapter 1…n for UI superscripts | Global per book/chapter policy if needed |
| **Chapter document** | Paragraph blocks only | Headings, poetry blocks, tables |
| **Search** | `plain_text` column exists; **no full-text search UI/API yet** | Postgres `tsvector` or external index |

---

## Rendering limits (ChapterLive)

- One **default translation** (`ScriptureText.get_default_translation/0` → `deuelbbk`).
- No verse-level highlighting, copy-with-reference, or parallel translations.
- Footnotes: list at bottom of chapter; inline superscript links (`¹`, `²`, …). No popover/tooltip v1.
- If import not run: placeholder with `mix scripture.import deuelbbk` hint.

---

## Known quality issues (re-import after parser fixes)

1. **`\add` / `\em` flattening** — Words inside character styles can appear out of order or as fragments in running text.
2. **Complex verses** — Multiple footnotes and `\add` in one verse (e.g. Matthew 27) may read awkwardly; content is still stored.
3. **Divine name `\nd`** — Rendered as plain “HERR” (no small caps / LORD styling).
4. **Footnote body** — Loses structure present in USFM (e.g. `\+em` inside `\ft`).

When fixing the parser, add a test fixture for the affected passage and re-run `mix scripture.import deuelbbk`.

---

## Licensing

- Elberfelder text is **copyrighted** (bibelkommentare.de / eBible.org).
- `copyright_notice` and `license` on `bible_translations` document local-dev import.
- Do **not** commit extracted USFM or redistribute text beyond your license terms.

---

## Maintenance checklist

When extending scripture text:

1. Update this file (supported / not supported / known issues).
2. Add or extend tests under `test/biblereader/scripture_text/` (fixture USFM in `test/support/fixtures/usfm/`).
3. Re-import: `mix scripture.import deuelbbk`.
4. Spot-check a chapter with footnotes in the browser (`/read/books/GEN/1`).
5. Mention migration impact if `content_json` or footnote schema changes.
