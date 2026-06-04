#!/usr/bin/env bash
# One-time PostgreSQL 16 setup for Bible Reader on the production VM.
# Run ON THE SERVER (or via: ssh user@server 'bash -s' < deploy/server-setup-postgres.sh)
#
# Creates a Podman container bound to 127.0.0.1 only, plus role/database for the app.
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-postgres-biblereader}"
VOLUME_NAME="${VOLUME_NAME:-biblereader_postgres_data}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_USER:-biblereader}"
PG_PASSWORD="${PG_PASSWORD:-}"
PG_DATABASE="${PG_DATABASE:-biblereader_prod}"

if [[ -z "$PG_PASSWORD" ]]; then
  echo "Error: set PG_PASSWORD before running (e.g. export PG_PASSWORD=\$(openssl rand -hex 24))"
  exit 1
fi

if ! command -v podman >/dev/null 2>&1; then
  cat <<'EOF'
Error: podman is not installed on this host.

Install PostgreSQL 16 with sudo, then create the app role/database:

  sudo apt-get update
  sudo apt-get install -y postgresql
  sudo -u postgres psql -v ON_ERROR_STOP=1 <<SQL
  DO $$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'biblereader') THEN
      CREATE ROLE biblereader LOGIN PASSWORD 'YOUR_PASSWORD';
    END IF;
  END $$;
  SELECT 'CREATE DATABASE biblereader_prod OWNER biblereader'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'biblereader_prod')\gexec
  SQL

Set DATABASE_URL in .env.production (URL-encode the password):

  ecto://biblereader:PASSWORD@127.0.0.1:5432/biblereader_prod

Or install podman and re-run this script with PG_PASSWORD set.

For apt postgresql-server instead, use:
  export PG_PASSWORD='same as DATABASE_URL password'
  sudo -E bash deploy/setup-postgres-apt.sh
EOF
  exit 1
fi

if ss -tln 2>/dev/null | grep -q ":${PG_PORT} " || netstat -tln 2>/dev/null | grep -q ":${PG_PORT} "; then
  if ! podman ps --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
    echo "Error: port ${PG_PORT} is in use but container ${CONTAINER_NAME} is not running."
    echo "Set PG_PORT=5433 (or another free port) and use that in DATABASE_URL."
    exit 1
  fi
  echo "Port ${PG_PORT} in use by existing ${CONTAINER_NAME}; skipping container create."
else
  echo "=== Starting PostgreSQL container on 127.0.0.1:${PG_PORT} ==="
  podman run -d \
    --name "$CONTAINER_NAME" \
    --replace \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_PASSWORD=postgres \
    -p "127.0.0.1:${PG_PORT}:5432" \
    -v "${VOLUME_NAME}:/var/lib/postgresql/data" \
    docker.io/library/postgres:16
fi

echo "=== Waiting for PostgreSQL ==="
for _ in $(seq 1 30); do
  if podman exec "$CONTAINER_NAME" pg_isready -U postgres >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

podman exec -e PGPASSWORD=postgres "$CONTAINER_NAME" psql -U postgres -v ON_ERROR_STOP=1 \
  -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${PG_USER}') THEN CREATE ROLE ${PG_USER} LOGIN PASSWORD '${PG_PASSWORD//\'/\'\'}'; ELSE ALTER ROLE ${PG_USER} WITH PASSWORD '${PG_PASSWORD//\'/\'\'}'; END IF; END \$\$;"

if ! podman exec "$CONTAINER_NAME" psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${PG_DATABASE}'" | grep -q 1; then
  podman exec "$CONTAINER_NAME" psql -U postgres -v ON_ERROR_STOP=1 \
    -c "CREATE DATABASE ${PG_DATABASE} OWNER ${PG_USER};"
fi

podman exec "$CONTAINER_NAME" psql -U postgres -v ON_ERROR_STOP=1 \
  -c "GRANT ALL PRIVILEGES ON DATABASE ${PG_DATABASE} TO ${PG_USER};"

ENCODED_PASSWORD=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''${PG_PASSWORD}''', safe=''))")

echo ""
echo "=== Add to .env.production on your workstation ==="
echo "DATABASE_URL=\"ecto://${PG_USER}:${ENCODED_PASSWORD}@127.0.0.1:${PG_PORT}/${PG_DATABASE}\""
echo ""
echo "Container: ${CONTAINER_NAME}  Volume: ${VOLUME_NAME}"
