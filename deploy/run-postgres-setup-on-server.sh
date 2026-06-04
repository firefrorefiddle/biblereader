#!/usr/bin/env bash
# Run deploy/setup-postgres-apt.sh on SERVER via SSH.
#
# Usage:
#   ./deploy/run-postgres-setup-on-server.sh --sudo-password 'your-vm-sudo-password'
#   SUDO_PASSWORD='…' ./deploy/run-postgres-setup-on-server.sh
#
# PG_PASSWORD is taken from DATABASE_URL in .env.production.
# Warning: passwords on the command line may appear in shell history and process listings.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SUDO_PASSWORD="${SUDO_PASSWORD:-}"

usage() {
  echo "Usage: $0 --sudo-password PASSWORD"
  echo "       SUDO_PASSWORD=PASSWORD $0"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sudo-password)
      [[ $# -ge 2 ]] || usage
      SUDO_PASSWORD="$2"
      shift 2
      ;;
    --sudo-password=*)
      SUDO_PASSWORD="${1#*=}"
      shift
      ;;
    -h | --help)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

if [[ -f .envrc ]]; then
  # shellcheck source=/dev/null
  source .envrc
fi

if [[ -z "${SERVER:-}" ]]; then
  echo "Error: SERVER not set in .envrc"
  exit 1
fi

if [[ ! -f .env.production ]]; then
  echo "Error: .env.production not found"
  exit 1
fi

if [[ -z "$SUDO_PASSWORD" ]]; then
  echo "Error: sudo password required for non-interactive SSH."
  echo "Use: $0 --sudo-password '…'  or  SUDO_PASSWORD='…' $0"
  exit 1
fi

DATABASE_URL=$(grep '^DATABASE_URL=' .env.production | cut -d= -f2- | tr -d '"')
PG_PASSWORD=$(python3 -c "
from urllib.parse import urlparse
u = urlparse('''${DATABASE_URL}''')
if not u.password:
    raise SystemExit('Could not parse password from DATABASE_URL')
print(u.password)
")

DEPLOY_USER="${DEPLOY_USER:-${USER:-}}"
SSH_OPTS=(-o StrictHostKeyChecking=no)

# printf %q produces safe single-quoted strings for remote bash
remote_pg=$(printf '%q' "$PG_PASSWORD")
remote_sudo=$(printf '%q' "$SUDO_PASSWORD")

echo "=== Running PostgreSQL setup on ${DEPLOY_USER}@${SERVER} ==="

ssh "${SSH_OPTS[@]}" "${DEPLOY_USER}@${SERVER}" \
  "export PG_PASSWORD=${remote_pg} SUDO_PASSWORD=${remote_sudo}; bash -s" \
  < "${ROOT_DIR}/deploy/setup-postgres-apt.sh"
