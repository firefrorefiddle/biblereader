#!/usr/bin/env bash
set -euo pipefail

# Load SERVER (and optional overrides) from repo-local envrc — never commit secrets here.
if [[ -f .envrc ]]; then
  # shellcheck source=/dev/null
  source .envrc
fi

if [[ -z "${SERVER:-}" ]]; then
  echo "Error: SERVER is not set. Define it in .envrc (e.g. export SERVER=your.host.example)."
  exit 1
fi

DEPLOY_USER="${DEPLOY_USER:-${USER:-}}"
APP_DIR="${APP_DIR:-/home/${DEPLOY_USER}/biblereader}"
DOMAIN="${DOMAIN:-biblereader.upscale-automation.com}"
REL_DIR="_build/prod/rel/biblereader"

RSYNC_RSH="ssh -o StrictHostKeyChecking=no"
SSH_OPTS=(-o StrictHostKeyChecking=no)

RUN_SEED=false

show_logs() {
  ssh "${SSH_OPTS[@]}" "${DEPLOY_USER}@${SERVER}" "journalctl --user -u biblereader -n 80 --no-pager"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --logs)
      show_logs
      exit 0
      ;;
    --seed)
      RUN_SEED=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--logs] [--seed]"
      exit 1
      ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f .env.production ]]; then
  echo "Error: .env.production not found. Create it from .env.production.example (not committed)."
  exit 1
fi

echo "=== Building production release locally ==="
export MIX_ENV=prod
mix deps.get --only prod
mix assets.deploy
mix release --overwrite

if [[ ! -d "$REL_DIR" ]]; then
  echo "Error: release not found at $REL_DIR"
  exit 1
fi

echo "=== Syncing release to ${DEPLOY_USER}@${SERVER}:${APP_DIR} ==="
ssh "${SSH_OPTS[@]}" "${DEPLOY_USER}@${SERVER}" "mkdir -p ${APP_DIR}"

rsync -avz --delete -e "$RSYNC_RSH" \
  "${REL_DIR}/" "${DEPLOY_USER}@${SERVER}:${APP_DIR}/"

echo "=== Syncing production env and systemd unit ==="
scp "${SSH_OPTS[@]}" .env.production "${DEPLOY_USER}@${SERVER}:${APP_DIR}/.env.production"
scp "${SSH_OPTS[@]}" systemd/user/biblereader.service \
  "${DEPLOY_USER}@${SERVER}:${APP_DIR}/biblereader.service"

load_env_and_run() {
  local remote_cmd=$1
  ssh "${SSH_OPTS[@]}" "${DEPLOY_USER}@${SERVER}" \
    "cd ${APP_DIR} && set -a && . ./.env.production && set +a && ${remote_cmd}"
}

echo "=== Running migrations on server ==="
load_env_and_run "./bin/migrate"

if [[ "$RUN_SEED" == true ]]; then
  echo "=== Seeding scripture catalog ==="
  load_env_and_run "./bin/biblereader eval BibleReader.Release.seed"
fi

echo "=== Installing user systemd unit ==="
ssh "${SSH_OPTS[@]}" "${DEPLOY_USER}@${SERVER}" "
  mkdir -p \"\${HOME}/.config/systemd/user\"
  cp \"${APP_DIR}/biblereader.service\" \"\${HOME}/.config/systemd/user/biblereader.service\"
  systemctl --user daemon-reload
  systemctl --user enable biblereader
  systemctl --user restart biblereader
  sleep 2
  if systemctl --user is-active --quiet biblereader; then
    echo 'biblereader started successfully'
  else
    echo 'biblereader failed to start'
    journalctl --user -u biblereader --no-pager -n 25
    exit 1
  fi
"

echo "=== Deployment complete ==="
echo "Public URL (after DNS + nginx + TLS): https://${DOMAIN}"
echo "Logs: $0 --logs"
