#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"

if [[ "${mode}" != "webserver" && "${mode}" != "daemon" ]]; then
  echo "Usage: $0 webserver|daemon" >&2
  exit 64
fi

for attempt in $(seq 1 30); do
  if dagster instance migrate; then
    break
  fi

  if [[ "${attempt}" == "30" ]]; then
    echo "PostgreSQL did not become ready after 30 attempts" >&2
    exit 1
  fi

  sleep 2
done

if [[ "${mode}" == "webserver" ]]; then
  exec dagster-webserver \
    --host 0.0.0.0 \
    --port "${PORT:-3000}" \
    --workspace workspace.yaml
fi

python ./scripts/daemon_health.py &
exec dagster-daemon run --workspace workspace.yaml
