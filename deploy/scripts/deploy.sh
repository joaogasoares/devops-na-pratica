#!/usr/bin/env bash
# Deploy da API na EC2 usando containers (Docker Compose).
# Executado pelo pipeline de CD via AWS SSM, mas também pode ser rodado manualmente:
#   sudo ./scripts/deploy.sh <uri-da-imagem-no-ECR:tag>
#
# Passos: login no ECR -> pull da imagem -> sobe a stack -> smoke test
#         -> em caso de falha, rollback automático para a versão anterior.
set -euo pipefail

IMAGE="${1:?Uso: deploy.sh <imagem:tag>}"
APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="$APP_DIR/docker-compose.prod.yml"
STATE_DIR="$APP_DIR/.state"
PROJECT_NAME="${PROJECT_NAME:-devops-na-pratica}"
ENVIRONMENT="${ENVIRONMENT:-prod}"

log() { echo "[deploy $(date -u +%H:%M:%S)] $*"; }

# Região extraída da própria URI do ECR: <conta>.dkr.ecr.<regiao>.amazonaws.com/<repo>:<tag>
REGISTRY="${IMAGE%%/*}"
AWS_REGION="${AWS_REGION:-$(echo "$REGISTRY" | sed -E 's/.*\.dkr\.ecr\.([a-z0-9-]+)\.amazonaws\.com/\1/')}"
export AWS_REGION
export LOG_GROUP="${LOG_GROUP:-/$PROJECT_NAME/$ENVIRONMENT/app}"
export APP_IMAGE="$IMAGE"

# Segredo lido do SSM Parameter Store (nunca fica no repositório)
GRAFANA_ADMIN_PASSWORD="$(aws ssm get-parameter \
  --name "/$PROJECT_NAME/$ENVIRONMENT/grafana-admin-password" \
  --with-decryption --query Parameter.Value --output text --region "$AWS_REGION")"
export GRAFANA_ADMIN_PASSWORD

mkdir -p "$STATE_DIR"
PREVIOUS_IMAGE="$(cat "$STATE_DIR/current_image" 2>/dev/null || true)"

log "Login no ECR ($REGISTRY)"
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY"

log "Baixando $IMAGE"
docker pull "$IMAGE"

log "Subindo a stack (API + Prometheus + Grafana)"
docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d --remove-orphans

if "$APP_DIR/scripts/smoke_test.sh" "http://localhost:8000"; then
  echo "$IMAGE" > "$STATE_DIR/current_image"
  [[ -n "$PREVIOUS_IMAGE" && "$PREVIOUS_IMAGE" != "$IMAGE" ]] && echo "$PREVIOUS_IMAGE" > "$STATE_DIR/previous_image"
  echo "$(date -u +%FT%TZ) $IMAGE" >> "$STATE_DIR/history.log"
  docker image prune -f > /dev/null
  log "Deploy concluído com sucesso: $IMAGE"
else
  log "Smoke test falhou para $IMAGE"
  if [[ -n "$PREVIOUS_IMAGE" ]]; then
    log "Iniciando rollback automático para $PREVIOUS_IMAGE"
    APP_IMAGE="$PREVIOUS_IMAGE" docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d
    "$APP_DIR/scripts/smoke_test.sh" "http://localhost:8000" && log "Rollback concluído"
  fi
  exit 1
fi
