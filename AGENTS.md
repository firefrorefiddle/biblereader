# Bible Reader — agent & contributor guidelines

This document orients AI assistants and human contributors to how we build **Bible Reader**: a Phoenix LiveView application backed by PostgreSQL, designed to grow from chapter-level read tracking into notes, community, and study tools without rewriting the core.

---

## Product vision (short)

**One place to read Scripture**—v1 presents the **entire Bible** as a browsable chapter list (book + chapter only; **no imposed reading order**). The reader logs chapters they have read (e.g. on paper); **each log records another read** of that chapter so the app can show **how often** each chapter has been read and aggregate **statistics** (rolling-window pace, estimates such as time to cover the whole Bible at current pace). Later: guided onboarding tour, per-chapter notes, key verses, community, and study features.

**Principle:** ship a small, solid vertical slice first; keep boundaries clean so new features add tables and contexts rather than tangling everything in one module.

---

## Tech stack

| Layer        | Choice                          | Notes |
|-------------|----------------------------------|-------|
| Runtime     | Elixir                          | OTP supervision, explicit failure handling |
| Web         | Phoenix + LiveView              | Server-rendered UI, minimal JS for enhancements only when needed |
| Data        | PostgreSQL                      | Source of truth; migrations versioned in repo |
| Real-time   | Phoenix PubSub (built-in)       | Future: presence, shared progress—not required for v1 |
| Jobs        | Oban (when needed)              | Defer until we have async work (emails, heavy imports) |

---

## High-level architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Web (Endpoint, Router)              │
├─────────────────────────────────────────────────────────────┤
│  LiveView (UI state, events)  ←→  Context modules (domain)  │
├─────────────────────────────────────────────────────────────┤
│  Ecto (Repo, schemas, queries)  ←→  PostgreSQL               │
└─────────────────────────────────────────────────────────────┘
```

### Bounded contexts (evolution path)

1. **`Scripture`** (v1 foundation)  
   Canonical book/chapter structure (seeded or migrated static data). Read-only reference data for “which chapters exist.” No user state here.

2. **`ReadingPlan`** (v1 feature)  
   User reading history: **append-only read events** per chapter (`user_id`, chapter ref, `read_at` in UTC). Derives per-chapter read counts, rolling-window stats, and pace/ETA queries. Not a “one checkbox per chapter forever”—**multiple reads** of the same chapter are first-class.

3. **Future (placeholders—not implemented until needed)**  
   - **`Notes`** — user notes per chapter (likely `user_id`, `book`, `chapter`, `body`, timestamps).  
   - **`Community`** — shared plans, follows, activity feeds; isolate behind contexts; prefer simple append-only activity tables until requirements justify heavier patterns.  
   - **`Study`** — key verses, cross-refs; may reference `Scripture` IDs.

**Rule:** new features get new context modules and schemas; **avoid** dumping unrelated concerns into `ReadingPlan` just because it was first.

### Data flow

- **LiveViews** call **context functions** (`ReadingPlan.log_chapter_read/...`, `ReadingPlan.stats_for_user/...`, etc.). They do not embed raw SQL or multi-table Ecto queries in the LiveView module.
- **Schemas** reflect tables; **changesets** validate writes; **queries** live in the context or dedicated query modules if they grow large (`ReadingPlan.Query`).

### Bible structure storage (v1)

- Prefer a **normalized** model: `books` (code, name, position, testament, **`in_protestant_canon`**, optional **`in_apocrypha`**) and `chapters` (`book_id`, `chapter_number`, maybe `verse_count` if useful later).  
- **Canon:** seeds use the **Protestant 66-book** canon as the default catalog. **Apocryphal / deuterocanonical** books are included in seeds but **hidden by default**; a **user preference** (`show_apocrypha: true`) reveals them in the UI (same list patterns, filtered in queries).  
- Alternative acceptable for v1: a **single seeded table** `scripture_chapters` with stable `(book_code, chapter_number)` if that reduces join noise; migrate to split tables if we need per-verse rows for notes/key verses.

**Stability:** use a **stable book identifier** (e.g. OSIS-style code or internal slug) in addition to display name, so translations/locales do not break foreign keys.

### Identifiers (extension hooks)

- **Book:** internal stable id (UUID or immutable slug/code) + human-readable name for UI.  
- **Chapter:** `(book_id, chapter_number)` for facts and for user progress rows—future **verse** rows can hang off the same `book_id` with `verse_number` without re-keying chapter progress.  
- **Reads:** each event references `book_id` + `chapter_number` (or FK to `chapters`) and **`read_at`**; aggregate **count** = `count(*)` per user/chapter. **Notes** / **Study** attach to the same keys later.

### v1 assumptions (explicit)

- **Auth:** **authenticated users only**—no guest progress; every read event belongs to a `user_id`.  
- **Timezone:** **profile-stored timezone** (IANA name, e.g. `Europe/Berlin`) drives any **calendar-day** grouping (if used beside rolling windows); store instants in UTC, convert for display and bucketing.  
- **Tenancy:** single-user namespace (`user_id` scopes all mutable data); no org/tenant column until a product need is defined—avoids speculative schema.  
- **Locale:** English UI and book names in seeds first; add Gettext / translated names when i18n becomes a requirement.  
- **Scripture text:** optional **licensed import** via USFM (see `ScriptureText` context). USFM archives stay on disk (`deuelbbk_usfm.zip` → `priv/scripture/usfm/`); the app reads **normalized JSON** in PostgreSQL (`chapter_documents`, `bible_verses`, `bible_footnotes`). User notes/highlights remain overlays, not edits to source text. Do not redistribute copyrighted text beyond documented license terms. **Import/parser limitations and future work:** [`docs/scripture-text-import.md`](docs/scripture-text-import.md).
- **Onboarding:** v1 can be minimal; **planned onboarding tour** is a later milestone (see product decisions).

---

## Elixir & Phoenix conventions

### Language style

- **Modules:** `PascalCase`. **Functions:** `snake_case`. **Atoms** for fixed states (`:completed`, `:old_testament`).
- Prefer **explicit** function heads and pattern matching over nested `if`/`case` when it clarifies control flow.
- **Pipe** (`|>`) for linear transformations; avoid pipes into one-argument lambdas that obscure errors—sometimes a named step is clearer.
- **Documentation:** `@moduledoc` and `@doc` for public context APIs and non-obvious behavior; skip noise on trivial getters.

### Errors

- Use **`{:ok, value}` / `{:error, reason}`** at context boundaries.  
- For form/LiveView, **`Ecto.Changeset`** errors are enough; translate to user-facing strings in the UI layer when needed.  
- Prefer **`with`** and pattern matching for expected failures; use **`try/rescue`** only for documented, narrow cases (e.g. boundary retries)—never rescue unknown errors to return fake `{:ok, _}`. Let supervisors handle unintended crashes.

### Phoenix (1.7+)

- **Controllers:** thin; JSON/HTML that isn’t LiveView stays minimal.  
- **Routes:** prefer **`~p`** / **verified routes** for compile-time-safe paths; group authenticated LiveViews in **`live_session`** with shared **`on_mount`** hooks to avoid duplicated `mount` logic.  
- **UI:** HEEx + **function components** (`CoreComponents`, `<.link>`, `<.form>`) as the default; keep templates thin.  
- **LiveView:**  
  - `mount/3` loads assigns; subscribe to PubSub only when needed.  
  - Keep **assigns flat** (`:chapters`, `:stats`, `:current_user`).  
  - **Handle events** by delegating to contexts; no business logic in templates.  
  - Large chapter lists: prefer **`stream/3`** + `phx-update="stream"` first; fall back to pagination/virtualization if needed.  
  - Use **`handle_async`** (when available in your LiveView version) for expensive reads so the LV process stays responsive—optional for v1.  
- **Extract** **`LiveComponent`s** when a subtree has its own state/events and the parent module grows unwieldy.

### Ecto

- **Migrations:** reversible when practical (`change/0` with `create`/`drop` pairs).  
- **Indexes:** add for foreign keys and common filters (`user_id`, `read_at` on read events; date-range queries for stats).  
- **Constraints:** DB-level unique indexes where a single row must be unique (e.g. `users.email`); **read events are not unique** per user/chapter—many rows per pair.  
- **Preloading:** avoid N+1 in LiveView `mount`/`handle_info`; use `preload` or explicit joins in context functions.  
- **Transactions:** use **`Ecto.Multi`** or **`Repo.transaction`** when multiple writes must succeed or fail together.  
- **Timestamps:** store **`read_at`** in **UTC**; convert using the **user’s profile timezone** (`tzdata` / `Calendar` or equivalent) when computing calendar buckets or showing local times.

### Stats at scale

- **v1:** derive stats from **append-only read events**; primary aggregates use a **rolling window** (e.g. last 7 / 30 days—**window length is a product constant** or user setting; document the chosen default in code and UI).  
- **Per-chapter frequency:** `count(*)` grouped by `(user_id, book_id, chapter_number)` or subquery over events.  
- If rollups become slow, add **daily summary** rows or **Oban**-scheduled aggregation—only when profiling says so.

### Testing

- **Contexts:** test public functions with the Ecto **Sandbox**—insert fixtures minimally; use **`async: true`** where safe.  
- **LiveView + DB:** use Sandbox **shared mode** when tests exercise LiveView and persistence together (see Phoenix docs for your version).  
- **LiveView:** `Phoenix.LiveViewTest` for critical flows (toggle chapter, stats update); follow docs for the **installed** Phoenix/LiveView version.  
- **Factories:** if complexity grows, `ExMachina` or small helper modules—don’t duplicate huge setup in every test.

### Security (baseline)

- **Authentication:** use a well-maintained solution (**Phoenix 1.7+** generators + `mix phx.gen.auth` pattern, or **Ueberauth** only when OAuth is required). Never roll crypto by hand.  
- **Authorization:** check user id on every mutating context call (`user_id` from `socket.assigns` must match resource).  
- **CSRF / sessions:** follow Phoenix defaults; LiveView is part of the same session.  
- **Input:** always validate through changesets; never interpolate user input into raw SQL.  
- **XSS:** HEEx escapes by default—avoid **`raw/1`** on user-controlled strings.  
- **Hardening:** consider stricter **headers** / **CSP** and **rate limiting** on auth endpoints in production.

---

## UI / LiveView specifics for this app

- **Chapter list:** show full Bible (Protestant canon by default; **optional apocrypha** when the user enables it). Group by book with collapsible sections; use **`stream/3`** or similar for large lists.  
- **Logging a read:** primary action **adds a read event** (not a one-time “done” checkbox). Optional “undo last read” for the current chapter can be a later UX nicety—**v1** can be append-only with no delete, or allow deleting only the most recent event—**decide in implementation** and keep tests aligned.  
- **Stats:** compute from persisted **`read_at` events**; rollups use the **rolling window** defined in product decisions; avoid deriving pace from session-only state.

---

## Privacy, GDPR, and cookies

We target **GDPR** compliance (EU users). Treat this as **engineering hygiene + legal review**, not a substitute for counsel.

- **Personal data:** account data (email, password hash), **reading history** (chapter read events), and **profile timezone** are personal data—minimize access, document purpose in a **privacy policy**, support **export/delete** when you add account management (required for GDPR for many deployments).  
- **Cookies / storage:** Phoenix **sessions** typically use a **cookie** (session id) for login and CSRF. That is often **strictly necessary** for the service; still **document** it in the privacy policy. **LiveView** uses WebSockets after the session is established.  
- **Cookie banner:** if you only use **essential** session cookies and no analytics/marketing cookies, many EU sites **do not** show a blocking “cookie banner” beyond a **privacy policy** link—**confirm with legal** for your jurisdiction and any third-party scripts (analytics, fonts, etc.). If you add **non-essential** cookies (e.g. analytics), you typically need **consent before setting** them.  
- **No “we don’t use cookies” claim** unless true—session cookies are still cookies. Prefer honest language: “We use essential cookies for login and security.”  
- **Processors / DPA:** document hosting (e.g. Postgres host, app host) and subprocessors if required.

---

## Operations & config

- **12-factor:** config via env (`DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_HOST`).  
- **Observability:** structured logging (`Logger` metadata: `user_id`, `request_id`); Phoenix/Ecto **Telemetry** events for metrics; add OpenTelemetry or similar when deploying seriously.  
- **Migrations:** run in release/deploy pipeline before app traffic.

### Local development database (Podman)

The project assumes a **PostgreSQL 16** instance for local dev, created with Podman (equivalent Docker image). **Do not** commit secrets; the password below is for **local dev only**.

```bash
podman run -d \
  --name postgres-dev \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=mydb \
  -p 5432:5432 \
  -v postgres_data:/var/lib/postgresql/data \
  docker.io/library/postgres:16
```

- **Host port:** `5432` (ensure nothing else binds the same port).  
- **Volume:** named volume `postgres_data` persists data across container restarts.  
- **`DATABASE_URL` for Ecto / Phoenix** (local dev)—set in `config/runtime.exs` / env or mirror in `config/dev.exs`:

  `postgresql://postgres:postgres@localhost:5432/mydb`

  `postgres://postgres:postgres@localhost:5432/mydb` is equivalent for many clients. Match the scheme your generated config expects; Ecto’s PostgreSQL adapter accepts standard PostgreSQL URIs.

- **Stopping / starting:** `podman stop postgres-dev` / `podman start postgres-dev`.  
- **Production:** use a managed Postgres or a properly secured deployment—**never** reuse these credentials.

### Production deployment (shared VM)

Deploy matches **gtd** / **songbook-oc** on `152.53.251.51`: [`deploy/deploy.sh`](deploy/deploy.sh) builds a **`mix release`** locally, rsyncs to `~/biblereader`, runs **`bin/migrate`**, user **systemd** on port **4000**, **nginx** → `biblereader.upscale-automation.com`. Postgres on the VM: **Podman** (`deploy/server-setup-postgres.sh`) or **apt** (see script when Podman is absent); do not reuse local dev credentials. Mail: **Swoosh Mailgun** (EU), same domain as songbook (`MAILGUN_*` in `.env.production`). **Status, procedure, troubleshooting:** [`docs/deployment.md`](docs/deployment.md).

### Developer experience

- Run **`mix format`** on every change; consider **Credo** (style) and **Dialyxir** (types) as the project matures. Once added to the project, **Credo** and **`mix test`** are part of **Definition of Done** (below).

---

## Git & review

- Small, focused commits; conventional messages encouraged (`feat:`, `fix:`, `chore:`).  
- PRs describe **behavior** and any **data migration** impact.  
- Schema changes: always include migration + rollback strategy notes if non-trivial.

---

## Definition of Done (mandatory for every task)

A task, feature, or fix is **not finished** until **all** items below are satisfied. **Agents and contributors must treat this as a gate:** do not report work complete or merge until every applicable bullet is done.

| Gate | Requirement |
|------|-------------|
| **Tests** | Automated tests **added or updated** to cover the change. **`mix test`** exits **0**. New behavior has assertions; regressions are prevented where feasible. Skip only where the repo explicitly documents an exception (e.g. pure config). |
| **Lint / format** | **`mix format`** run on touched Elixir files. If the project includes **Credo** (or another linter in `mix.exs`), it passes with **no new violations** the project treats as failures. Fix or justify any new warnings per team rules. |
| **Documentation** | **Public** context modules and non-obvious functions have **`@moduledoc` / `@doc`**. User-facing or operator-facing behavior changes are reflected in the **right place** (this file, README, or inline—minimal but sufficient). Config env vars (e.g. `DATABASE_URL`) stay discoverable. |
| **Review** | **Self-review** at minimum: diff read for clarity, **AGENTS.md** alignment, no stray `IO.inspect` / debug, auth and data access considered. If the workflow uses **human PR review**, approval is required before merge. |
| **Commit** | Changes are **committed** to version control with a **clear conventional message** (`feat:`, `fix:`, `chore:`, `docs:`, etc.). If using branches/PRs: branch pushed, PR description summarizes behavior and migration risk, and the PR is **merge-ready** (CI green if present). |

**Order of operations (recommended):** implement → format → lint → test → document → self-review → commit (→ PR if applicable).

**v1 checklist items** (below) each count as **done** only when they also meet this Definition of Done.

---

## What “done” looks like for v1 (implementation checklist)

Each row is complete only when it satisfies **[Definition of Done](#definition-of-done-mandatory-for-every-task)** above.

- [x] Phoenix app with LiveView and PostgreSQL configured  
- [x] Seeded scripture catalog: **Protestant 66** by default; **apocrypha** in data with **user toggle** to show  
- [x] **Auth required**; user profile includes **timezone** (IANA) for stats  
- [x] User can **log a chapter read** (append-only events); UI shows **read count** (or equivalent) per chapter 
- [x] **Reading workflow UI**: home dashboard (`/read`), book chapter grid (`/read/books/:code`), chapter view with notes (`/read/books/:code/:n`) 
- [x] **Scripture text (optional import):** USFM → normalized DB; chapter view renders text + footnotes when `mix scripture.import deuelbbk` has been run 
- [x] Stats: **rolling-window** pace / activity; ETA-style metrics derived from documented formulas  
- [x] Privacy policy link + honest description of session/essential cookies; GDPR-minded data handling  
- [x] Tests for context logic and main LiveView interactions  

---

## Out of scope for first iteration

- Full verse-level text (licensing, UX, search)—**basic import + footnotes** supported via `ScriptureText`; apocrypha text, cross-refs, Strong’s, morphology still later (see [`docs/scripture-text-import.md`](docs/scripture-text-import.md))
- Mobile apps (web-first responsive LiveView)  
- Heavy social features—design hooks only (user ids, timestamps) where they don’t slow v1  

---

## Resolved product decisions (source of truth)

| Topic | Decision |
|-------|----------|
| **Guests** | **Authenticated only**—no anonymous progress. |
| **Timezone** | **Profile timezone** (IANA); UTC in DB; convert for display and any calendar bucketing. |
| **Reading order** | **None imposed.** Full Bible presented; user logs **chapter reads** in any order. |
| **Re-reads** | **Each log is a new read** of that chapter; app tracks **how often** each chapter was read. |
| **Stats** | **Rolling window** (e.g. 7/30 days—pick default window(s) in code and document). |
| **Canon** | **Protestant 66** default catalog; **optional UI to include apocryphal books** (seeded, hidden until enabled). |
| **Onboarding** | **Guided tour / plan onboarding**—**later**; v1 can be minimal. |
| **GDPR / cookies** | **EU GDPR** posture: privacy policy, data minimization, export/delete path when accounts mature; **do not** claim “no cookies” if session cookies exist—**essential cookies** for login + document; **cookie banner** only if/when non-essential cookies (e.g. analytics) are added—**legal review** recommended. |

### Remaining open questions (smaller)

- **Rolling window length(s):** default **7** vs **30** days (or both) for primary stats.  
- **ETA formula:** e.g. chapters remaining ÷ average chapters per day in window—document in code once chosen.  
- **Undo:** remove last event vs. delete-any vs. never—v1 UX choice.  
- **API / mobile:** still LiveView-first until explicitly scoped.

---

## Document maintenance

This file should be updated as contexts split, Phoenix/LiveView versions are pinned, and new dependencies (Oban, etc.) land. Pin **`mix.exs`** / **`.tool-versions`** and reference the matching Phoenix docs from README or here when the stack is generated.
