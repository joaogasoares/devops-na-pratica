#!/usr/bin/env bash
# Smoke test pós-deploy: confirma que a API está no ar e funcionando.
#   ./smoke_test.sh http://localhost:8000
set -euo pipefail

BASE_URL="${1:-http://localhost:8000}"
TENTATIVAS="${TENTATIVAS:-20}"

for i in $(seq 1 "$TENTATIVAS"); do
  if curl -fsS "$BASE_URL/health" > /dev/null 2>&1; then
    break
  fi
  [ "$i" -eq "$TENTATIVAS" ] && { echo "[smoke] /health não respondeu em $BASE_URL"; exit 1; }
  sleep 3
done

curl -fsS "$BASE_URL/health" | grep -q '"status":"ok"' || { echo "[smoke] /health inválido"; exit 1; }
curl -fsS "$BASE_URL/tasks" > /dev/null || { echo "[smoke] /tasks falhou"; exit 1; }
curl -fsS "$BASE_URL/metrics" | grep -q "http_requests_total" || { echo "[smoke] /metrics falhou"; exit 1; }

echo "[smoke] OK - $BASE_URL respondendo corretamente"
