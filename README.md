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

Production runs on the same VM as **songbook-oc** and **gtd** (`152.53.251.51`): user-level **systemd**, **nginx** TLS, app on **`127.0.0.1:4000`**, public URL **`https://biblereader.upscale-automation.com`**.

### One-time server setup

1. **DNS**: Point `biblereader.upscale-automation.com` A/AAAA at the server.

2. **PostgreSQL** on the VM (localhost only). The shared host may not have Podman; use whichever applies:

   - **Podman** (if installed): `export PG_PASSWORD="$(openssl rand -hex 24)"` then `bash deploy/server-setup-postgres.sh` on the server.
   - **Otherwise** (requires sudo): follow the apt/PostgreSQL instructions printed when the script exits without Podman, or install PostgreSQL 16 and create role `biblereader` / database `biblereader_prod` matching `DATABASE_URL` in `.env.production`.

   Copy the final `DATABASE_URL` into `.env.production` on your workstation (must match the password you set on the server).

3. **Secrets**: Copy [`.env.production.example`](.env.production.example) to **`.env.production`**, set `SECRET_KEY_BASE` (`mix phx.gen.secret`), `DATABASE_URL`, and Mailgun vars (same EU account as songbook-oc: `MAILGUN_*`, `MAIL_FROM`).

4. **Deploy credentials**: Copy [`.envrc.example`](.envrc.example) to **`.envrc`** with `SERVER` and `DOMAIN`.

5. **Nginx**: Install [`deploy/nginx-biblereader.upscale-automation.com.conf`](deploy/nginx-biblereader.upscale-automation.com.conf) under `/etc/nginx/sites-available/`, enable, test, reload.

6. **TLS**: `sudo certbot --nginx -d biblereader.upscale-automation.com`

7. **User lingering** (if services stop after SSH logout): `loginctl enable-linger "$USER"`

### Deploy from your workstation

```bash
chmod +x deploy/deploy.sh
./deploy/deploy.sh --seed   # first deploy: migrate + seed catalog
./deploy/deploy.sh          # later deploys: build release, rsync, migrate, restart
```

Logs: `./deploy/deploy.sh --logs`

### Verification

```bash
curl -sI https://biblereader.upscale-automation.com/
```

Register, log in, open `/read`, and confirm LiveView works over HTTPS. Password-reset email should use links on `biblereader.upscale-automation.com` (Mailgun EU).

## Learn more

- Phoenix: https://www.phoenixframework.org/
- Guides: https://hexdocs.pm/phoenix/overview.html
