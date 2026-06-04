# Bible Reader

Phoenix LiveView app to log Bible chapter reads (paper-friendly), track per-chapter counts, and show rolling-window statistics. See [`AGENTS.md`](AGENTS.md) for architecture and conventions.

## Requirements

- Elixir 1.14+ and Erlang/OTP (see `mix.exs`)
- PostgreSQL 16 (local dev example in `AGENTS.md` under **Local development database (Podman)**)

## Setup

1. Start PostgreSQL and create a database (default dev config expects database `mydb`, user `postgres`, password `postgres`, host `localhost` — see `config/dev.exs`).
2. Install dependencies and initialize the database:

```bash
mix deps.get
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs
```

Or: `mix setup` (runs `ecto.setup`, which includes `seeds.exs`).

3. **Optional:** import Elberfelder Bible text from USFM:

```bash
mix scripture.import deuelbbk
```

On first run, place `deuelbbk_usfm.zip` in the project root (or copy USFM files into `priv/scripture/usfm/deuelbbk/` yourself). The task unzips once, then loads into PostgreSQL. You can delete the zip after that; re-import only needs the extracted `.usfm` files. Without import, chapter pages still work for logging reads and notes, but show a hint instead of scripture text.

**Import limitations** (supported markers, known text-quality gaps, future work): [`docs/scripture-text-import.md`](docs/scripture-text-import.md).

4. Start the server:

```bash
mix phx.server
```

Visit [http://localhost:4000](http://localhost:4000), register an account, then open **Read** (`/read`) to browse chapters and log reads.

## Testing

```bash
mix test
```

## Deployment (production)

Production targets the shared VM (`152.53.251.51`) at **`https://biblereader.upscale-automation.com`**, same pattern as songbook-oc and gtd (user systemd, nginx TLS, `mix release` + rsync).

**Full status checklist, one-time setup, routine deploy, env vars, and troubleshooting:** [`docs/deployment.md`](docs/deployment.md).

Quick start (after Postgres, DNS, nginx, and `.env.production` / `.envrc` exist):

```bash
./deploy/deploy.sh --seed   # first deploy
./deploy/deploy.sh          # later releases
./deploy/deploy.sh --logs
```

## Learn more

- Phoenix: https://www.phoenixframework.org/
- Guides: https://hexdocs.pm/phoenix/overview.html
