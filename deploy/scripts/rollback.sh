#!/usr/bin/env bash
# Rollback manual: volta para a versão anterior registrada pelo deploy.sh
# (ou para uma imagem específica passada como argumento).
#   sudo ./scripts/rollback.sh [imagem:tag]
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-$(cat "$APP_DIR/.state/previous_image" 2>/dev/null || true)}"

if [ -z "$TARGET" ]; then
  echo "Nenhuma versão anterior registrada. Informe a imagem: rollback.sh <imagem:tag>" >&2
  exit 1
fi

echo "[rollback] Voltando para $TARGET"
exec "$APP_DIR/scripts/deploy.sh" "$TARGET"
