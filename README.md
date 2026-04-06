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

3. Start the server:

```bash
mix phx.server
```

Visit [http://localhost:4000](http://localhost:4000), register an account, then open **Read** (`/read`) to browse chapters and log reads.

## Testing

```bash
mix test
```

## Learn more

- Phoenix: https://www.phoenixframework.org/
- Guides: https://hexdocs.pm/phoenix/overview.html
