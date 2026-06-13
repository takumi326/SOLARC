#!/usr/bin/env bash
# Docker Compose の API 用 DB に migration + seed を一度流す（初回・DB 作り直し後）。
# 前提: `docker compose up -d db` などで db が起動済み。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> db:migrate (development) + db:seed"
docker compose run --rm api bash -lc "cd /app/api && bundle exec rails db:migrate && bundle exec rails db:seed"

echo "==> db:test:prepare"
docker compose run --rm api bash -lc "cd /app/api && bundle exec rails db:test:prepare"

echo "Done."
