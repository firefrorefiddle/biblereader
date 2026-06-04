#!/usr/bin/env bash
# Create Bible Reader role and database on a host with apt postgresql (peer auth for postgres).
#
# Run ON THE SERVER:
#   export PG_PASSWORD='your-app-password'
#   export SUDO_PASSWORD='your-linux-sudo-password'   # if not root and sudo needs a password
#   bash deploy/setup-postgres-apt.sh
#
# From workstation (see run-postgres-setup-on-server.sh):
#   ./deploy/run-postgres-setup-on-server.sh --sudo-password '…'
set -euo pipefail

PG_USER="${PG_USER:-biblereader}"
PG_DATABASE="${PG_DATABASE:-biblereader_prod}"
PG_PASSWORD="${PG_PASSWORD:-}"
SUDO_PASSWORD="${SUDO_PASSWORD:-}"

if [[ -z "$PG_PASSWORD" ]]; then
  echo "Error: set PG_PASSWORD (must match DATABASE_URL in .env.production)."
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "Error: psql not found. Install with: sudo apt-get install -y postgresql"
  exit 1
fi

# Escape single quotes for SQL string literal
sql_password="${PG_PASSWORD//\'/\'\'}"

sudo_as_postgres() {
  if [[ "$(id -u)" -eq 0 ]]; then
    su - postgres -c "$*"
  elif [[ -n "$SUDO_PASSWORD" ]]; then
    printf '%s\n' "$SUDO_PASSWORD" | sudo -S -p '' -u postgres "$@"
  else
    sudo -u postgres "$@"
  fi
}

run_psql() {
  sudo_as_postgres psql -v ON_ERROR_STOP=1 -c "$1"
}

echo "=== Creating/updating role ${PG_USER} ==="
run_psql "DO \$\$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${PG_USER}') THEN
    CREATE ROLE ${PG_USER} LOGIN PASSWORD '${sql_password}';
  ELSE
    ALTER ROLE ${PG_USER} WITH LOGIN PASSWORD '${sql_password}';
  END IF;
END \$\$;"

echo "=== Creating database ${PG_DATABASE} (if missing) ==="
exists=$(sudo_as_postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${PG_DATABASE}'")

if echo "$exists" | grep -q 1; then
  echo "Database ${PG_DATABASE} already exists."
else
  run_psql "CREATE DATABASE ${PG_DATABASE} OWNER ${PG_USER};"
fi

run_psql "GRANT ALL PRIVILEGES ON DATABASE ${PG_DATABASE} TO ${PG_USER};"

echo "=== Schema privileges (PostgreSQL 15+) ==="
sudo_as_postgres psql -d "${PG_DATABASE}" -v ON_ERROR_STOP=1 -c "GRANT ALL ON SCHEMA public TO ${PG_USER};"

echo "=== Verifying TCP login as ${PG_USER} ==="
export PGPASSWORD="$PG_PASSWORD"
psql -h 127.0.0.1 -U "$PG_USER" -d "$PG_DATABASE" -tAc "SELECT 'ok' AS connected;" | grep -q ok
unset PGPASSWORD

ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''${PG_PASSWORD}''', safe=''))")
echo ""
echo "=== DATABASE_URL for .env.production ==="
echo "DATABASE_URL=\"ecto://${PG_USER}:${ENCODED}@127.0.0.1:5432/${PG_DATABASE}\""
echo ""
echo "PostgreSQL setup complete."
