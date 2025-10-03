#!/bin/bash
set -euo pipefail

: "${IMAGE_TAG:?A variável IMAGE_TAG não foi definida.}"
: "${COMMIT_SHA:?A variável COMMIT_SHA não foi definida.}"
: "${PROJECT_NAME:?A variável PROJECT_NAME não foi definida.}"
: "${PROJECT_DIR:?A variável PROJECT_DIR não foi definida.}"
: "${REPO_FULL_NAME:?A variável REPO_FULL_NAME não foi definida.}"

export SERVICE_NAME=${PROJECT_NAME}
export HOSTNAME="${PROJECT_NAME}.carlosalexandre.com.br"
export ROUTER_NAME="${PROJECT_NAME}"
export COMPOSE_FILE="docker-compose.production.yml"

trap 'echo "--- [ERRO] O deploy falhou. Coletando informações para debug... ---"; docker compose -f ${COMPOSE_FILE} -p ${SERVICE_NAME} ps || true; echo "--- Logs (últimas 200 linhas) ---"; docker compose -f ${COMPOSE_FILE} -p ${SERVICE_NAME} logs --no-color --tail=200 || true' ERR

echo "🚀 Iniciando deploy de produção para o commit ${COMMIT_SHA}..."
echo "-> Imagem: ${REPO_FULL_NAME}:${IMAGE_TAG}"

cd "${PROJECT_DIR}"

if [ ! -f .env ]; then
    echo "❌ Erro Crítico: O arquivo .env não foi encontrado em ${PROJECT_DIR}."
    echo "   Por segurança, o .env de produção deve ser criado manualmente no servidor."
    exit 1
fi

echo "🔄 Atualizando o código-fonte (ex: docker-compose.yml)..."
git fetch origin
git checkout "${COMMIT_SHA}"

docker compose -f "${COMPOSE_FILE}" -p "${SERVICE_NAME}" pull app

echo "⬆️  Atualizando os serviços com Docker Compose..."
docker compose -f docker-compose.production.yml -p "${SERVICE_NAME}" up -d --pull=always --remove-orphans

docker compose -f docker-compose.production.yml -p "${SERVICE_NAME}" up -d --no-deps nginx --force-recreate

echo "⏳ Aguardando a aplicação (app) ficar saudável (healthy)..."
APP_TIMEOUT=120
until [ "$(docker inspect --format='{{json .State.Health.Status}}' "$(docker compose -f ${COMPOSE_FILE} -p ${SERVICE_NAME} ps -q app)" 2>/dev/null | tr -d '"')" = "healthy" ]; do
  sleep 2
  APP_TIMEOUT=$((APP_TIMEOUT-2))
  if [ $APP_TIMEOUT -le 0 ]; then
    echo "❌ Erro: A aplicação não ficou 'healthy' a tempo." >&2
    exit 1
  fi
done
echo "✅ Aplicação saudável."

echo "🔧 Executando otimizações e migrações do Laravel..."
docker compose -f "${COMPOSE_FILE}" -p "${SERVICE_NAME}" exec -T app php artisan config:cache
docker compose -f "${COMPOSE_FILE}" -p "${SERVICE_NAME}" exec -T app php artisan route:cache
docker compose -f "${COMPOSE_FILE}" -p "${SERVICE_NAME}" exec -T app php artisan view:cache
docker compose -f "${COMPOSE_FILE}" -p "${SERVICE_NAME}" exec -T app php artisan migrate --force
echo "✅ Migrações e otimizações concluídas."

echo "Verificando readiness HTTP de https://${HOSTNAME}/health ..."
READY_TIMEOUT=60
while true; do
  HTTP_CODE=$(curl -k -sS -o /dev/null -w "%{http_code}" --max-time 5 "https://${HOSTNAME}/health")
  if [ "$HTTP_CODE" -eq 200 ]; then
    echo "✅ Readiness OK (200) em ${HOSTNAME}."
    break
  else
    sleep 2
    READY_TIMEOUT=$((READY_TIMEOUT-2))
    if [ $READY_TIMEOUT -le 0 ]; then
      echo "Erro: readiness HTTP não atingido. Último código: ${HTTP_CODE}" >&2
      exit 1
    fi
  fi
done

echo "🧹 Limpando imagens Docker antigas..."
docker image prune -af

echo "🎉 Deploy em produção concluído com sucesso!"
