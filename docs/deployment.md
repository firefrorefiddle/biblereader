# Production deployment

Bible Reader deploys to the **same VM** as [songbook-oc](https://github.com/firefrorefiddle/songbook-oc) and **gtd**: manual **`mix release`** build on your workstation, **rsync**, **user systemd**, **nginx** TLS termination, **PostgreSQL** on localhost, **Mailgun EU** (shared with songbook-oc).

## Deployment status

Use this checklist to see what is done versus what is still required for a **live** site at `https://biblereader.upscale-automation.com`.

| Item | In repository | Typical production state |
|------|---------------|---------------------------|
| Release build (`mix release`, `rel/overlays`) | Done | Release tarball deployed under `~/biblereader` |
| [`deploy/deploy.sh`](../deploy/deploy.sh) | Done | Run from workstation after `.env.production` exists |
| User systemd unit | Done | `~/.config/systemd/user/biblereader.service` |
| Nginx site snippet | Done | Requires **sudo** install on VM |
| TLS (certbot) | Documented | Requires DNS + nginx first |
| `.env.production` / `.envrc` | Examples only (gitignored) | Operator creates locally; scp’d each deploy |
| PostgreSQL 16 | Setup scripts | Install `postgresql` on VM; run [`deploy/setup-postgres-apt.sh`](../deploy/setup-postgres-apt.sh) (sudo) |
| DNS `biblereader.upscale-automation.com` | Documented | Operator / DNS provider |
| App serving traffic | After above | `systemctl --user status biblereader` active, port **4000** |

**Last known blocker:** PostgreSQL was not listening on `127.0.0.1:5432` on the shared host, so `bin/migrate` failed until the database is installed and `DATABASE_URL` matches. After Postgres is up, re-run `./deploy/deploy.sh --seed`.

Update the “Typical production state” column on your team when milestones complete.

## Architecture

| Component | Value |
|-----------|--------|
| Server | `152.53.251.51` (same as songbook-oc / gtd) |
| SSH user | Your deploy user (default: local `$USER`) |
| App directory | `~/biblereader` |
| App listen | `127.0.0.1:4000` (not public; nginx proxies) |
| Public URL | `https://biblereader.upscale-automation.com` |
| Sibling ports | songbook **3000**, gtd **3102** — do not reuse |

```mermaid
flowchart LR
  laptop[Workstation mix release] -->|rsync + scp env| vm[VM 152.53.251.51]
  vm --> systemd[user systemd biblereader]
  systemd --> app[127.0.0.1:4000]
  nginx[nginx TLS] --> app
  users[Browser] --> nginx
  app --> pg[PostgreSQL localhost]
  app --> mg[Mailgun EU]
```

There is **no in-repo CI/CD**; deploy is operator-driven.

## Prerequisites (workstation)

1. Elixir/Erlang matching `mix.exs` (Linux x86_64 build for this VM).
2. SSH access to the server.
3. Copy [`.envrc.example`](../.envrc.example) → **`.envrc`** (gitignored):

   ```bash
   export SERVER="152.53.251.51"
   export DOMAIN="biblereader.upscale-automation.com"
   ```

4. Copy [`.env.production.example`](../.env.production.example) → **`.env.production`** (gitignored). Set:
   - `SECRET_KEY_BASE` — `mix phx.gen.secret`
   - `DATABASE_URL` — must match production Postgres (URL-encode password)
   - `MAILGUN_*`, `MAIL_FROM` — same EU Mailgun account as songbook-oc (`mg.upscale-automation.com`)

## One-time server setup

### 1. DNS

Point **`biblereader.upscale-automation.com`** A/AAAA records at **`152.53.251.51`**.

### 2. PostgreSQL

Database must be reachable at **`127.0.0.1:5432`** from the app user (or set `PG_PORT` / `DATABASE_URL` consistently).

**Option A — Podman** (if installed on the VM):

```bash
export PG_PASSWORD="$(openssl rand -hex 24)"
bash deploy/server-setup-postgres.sh   # run on the server
```

**Option B — apt** (`postgresql` / `postgresql-server` on the VM; needs sudo):

1. Set **`DATABASE_URL`** in workstation **`.env.production`** first (generate password with `openssl rand -hex 24`, URL-encode special chars in the URL).

   ```bash
   DATABASE_URL="ecto://biblereader:PASSWORD@127.0.0.1:5432/biblereader_prod"
   ```

2. Create role and database (password must match `DATABASE_URL`):

   ```bash
   # From repo root (sudo password required over non-interactive SSH):
   ./deploy/run-postgres-setup-on-server.sh --sudo-password 'your-vm-sudo-password'
   ```

   Or on the **server** after `git pull` / copying the script:

   ```bash
   export PG_PASSWORD='same-as-in-.env.production'
   sudo -E bash deploy/setup-postgres-apt.sh
   ```

   This creates role **`biblereader`**, database **`biblereader_prod`**, and verifies TCP login on `127.0.0.1:5432`.

### 3. Nginx

```bash
sudo cp deploy/nginx-biblereader.upscale-automation.com.conf \
  /etc/nginx/sites-available/biblereader.upscale-automation.com
sudo ln -sf /etc/nginx/sites-available/biblereader.upscale-automation.com \
  /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

The snippet includes **WebSocket** headers required for LiveView (`/live`).

### 4. TLS

After HTTP works:

```bash
sudo certbot --nginx -d biblereader.upscale-automation.com
```

### 5. User lingering (if needed)

If `systemctl --user` services stop after you disconnect SSH:

```bash
loginctl enable-linger "$USER"
```

## Deploy procedure (every release)

From the **repository root**:

```bash
chmod +x deploy/deploy.sh

# First successful deploy (after Postgres is up):
./deploy/deploy.sh --seed

# Later deploys:
./deploy/deploy.sh
```

What the script does:

1. `MIX_ENV=prod` — `mix deps.get --only prod`, `mix assets.deploy`, `mix release --overwrite`
2. **rsync** `_build/prod/rel/biblereader/` → `SERVER:~/biblereader/`
3. **scp** `.env.production` and install `systemd/user/biblereader.service`
4. On server (with env loaded): **`./bin/migrate`**
5. Optional **`--seed`**: `bin/biblereader eval BibleReader.Release.seed` (scripture catalog; idempotent)
6. **`systemctl --user restart biblereader`**

**Logs:**

```bash
./deploy/deploy.sh --logs
# or on server:
journalctl --user -u biblereader -f
```

### Optional: scripture text on production

USFM import is not part of `deploy.sh`. After deploy, from the server (with DB up), run import via release eval or a one-off admin task; see [`scripture-text-import.md`](scripture-text-import.md). Dev workflow: `mix scripture.import deuelbbk` locally.

## Verification

```bash
# TLS / nginx
curl -sI https://biblereader.upscale-automation.com/

# On server (loopback)
curl -sI http://127.0.0.1:4000/
systemctl --user is-active biblereader
```

Functional checks:

- Register / log in over HTTPS
- Open **`/read`**, log a chapter read (LiveView + WebSocket)
- Password reset email: links must use **`biblereader.upscale-automation.com`** (check `PHX_HOST` and Mailgun)

## Environment variables (production)

| Variable | Required | Notes |
|----------|----------|--------|
| `DATABASE_URL` | Yes | Ecto URL to localhost Postgres |
| `SECRET_KEY_BASE` | Yes | Cookie signing |
| `PHX_HOST` | Yes | Public hostname for URL generation in emails |
| `PORT` | No | Default `4000` |
| `POOL_SIZE` | No | Default `10` |
| `PHX_SERVER` | Set in systemd | `true` — enables HTTP server in release |
| `MAILGUN_API_KEY` | Yes | Production mail |
| `MAILGUN_DOMAIN` | Yes | e.g. `mg.upscale-automation.com` |
| `MAILGUN_BASE_URL` | No | Default `https://api.eu.mailgun.net` |
| `MAIL_FROM` | Yes | e.g. `BibleReader <postmaster@mg.upscale-automation.com>` |

Loaded from **`~/biblereader/.env.production`** (systemd `EnvironmentFile` and `deploy.sh` migrate/seed commands).

## Troubleshooting

| Symptom | Likely cause | Action |
|---------|----------------|--------|
| `DATABASE_URL is missing` on migrate | Env not loaded | Ensure `.env.production` exists on server; deploy script sources it for `bin/migrate` |
| `connection refused` on `127.0.0.1:5432` | Postgres not running | Complete [PostgreSQL setup](#2-postgresql) |
| `mix release` prompts Overwrite? | Old release dir | Script uses `--overwrite`; run `./deploy/deploy.sh` not bare `mix release` |
| LiveView disconnects | Nginx WebSocket | Use repo nginx snippet; check `proxy_read_timeout` |
| Email links point to `example.com` | `PHX_HOST` | Set `PHX_HOST=biblereader.upscale-automation.com` in `.env.production` |
| Service inactive after logout | No lingering | `loginctl enable-linger "$USER"` |

## Related files

| Path | Purpose |
|------|---------|
| [`deploy/deploy.sh`](../deploy/deploy.sh) | Main deploy script |
| [`deploy/setup-postgres-apt.sh`](../deploy/setup-postgres-apt.sh) | Role/DB on apt PostgreSQL (sudo on VM) |
| [`deploy/run-postgres-setup-on-server.sh`](../deploy/run-postgres-setup-on-server.sh) | Run apt setup via SSH (reads password from `.env.production`) |
| [`deploy/server-setup-postgres.sh`](../deploy/server-setup-postgres.sh) | Postgres bootstrap via Podman |
| [`deploy/nginx-biblereader.upscale-automation.com.conf`](../deploy/nginx-biblereader.upscale-automation.com.conf) | Nginx vhost |
| [`systemd/user/biblereader.service`](../systemd/user/biblereader.service) | User unit |
| [`lib/biblereader/release.ex`](../lib/biblereader/release.ex) | `migrate/0`, `seed/0` |
| [`config/runtime.exs`](../config/runtime.exs) | Prod env, Mailgun, endpoint |
| [`.env.production.example`](../.env.production.example) | Secret template |
