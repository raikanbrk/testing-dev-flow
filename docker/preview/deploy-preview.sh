#!/bin/bash
set -euo pipefail

: "${PR_NUMBER:?A variável PR_NUMBER não foi definida.}"
: "${IMAGE_TAG:?A variável IMAGE_TAG não foi definida.}"
: "${COMMIT_SHA:?A variável COMMIT_SHA não foi definida.}"
: "${PROJECT_DIR:?A variável PROJECT_DIR não foi definida.}"
: "${PROJECT_NAME:?A variável PROJECT_NAME não foi definida.}"

export HOSTNAME="${PROJECT_NAME}-pr-${PR_NUMBER}.preview.carlosalexandre.com.br"
export ROUTER_NAME="${PROJECT_NAME}-pr-${PR_NUMBER}"
export SERVICE_NAME="${PROJECT_NAME}-pr-${PR_NUMBER}"
export IMAGE_TAG

trap 'echo "--- docker compose ps ---"; docker compose -f docker-compose.preview.yml -p ${SERVICE_NAME} ps || true; echo "--- docker compose logs (last 200 lines) ---"; docker compose -f docker-compose.preview.yml -p ${SERVICE_NAME} logs --no-color --tail=200 || true' ERR

echo "Iniciando deploy para PR #${PR_NUMBER}..."

if $FIRST_TIME; then
  cp .env.preview .env
  sed -i "s#^APP_URL=.*#APP_URL=https://${HOSTNAME}#" .env

  KEY=$(openssl rand -base64 32 | sed 's/^/base64:/')
  sed -i "s#^APP_KEY=.*#APP_KEY=${KEY}#" .env

  ln -s ~/.htpasswd ./docker/nginx/.htpasswd || true
fi

echo "Atualizando repositório para o commit ${COMMIT_SHA}..."
git fetch origin
git checkout "${COMMIT_SHA}"

cd "${PROJECT_DIR}"
docker compose -f docker-compose.preview.yml -p "${SERVICE_NAME}" pull app

echo "Subindo os contêineres com a imagem ${IMAGE_TAG}..."
docker compose -f docker-compose.preview.yml -p "${SERVICE_NAME}" up -d --pull=always

echo "Aguardando o banco de dados ficar pronto..."
TIMEOUT=60
while ! docker compose -f docker-compose.preview.yml -p "${SERVICE_NAME}" exec -T mysql mysqladmin ping --silent; do
  sleep 1
  TIMEOUT=$((TIMEOUT-1))
  if [ $TIMEOUT -le 0 ]; then
    echo "Erro: O banco de dados não ficou pronto a tempo." >&2
    exit 1
  fi
done
echo "✅ Banco de dados pronto!"

echo "Aguardando health do app (FPM)..."
APP_TIMEOUT=120
until [ "$(docker inspect --format='{{json .State.Health.Status}}' "$(docker compose -f docker-compose.preview.yml -p ${SERVICE_NAME} ps -q app)" 2>/dev/null | tr -d '"')" = "healthy" ]; do
  sleep 2
  APP_TIMEOUT=$((APP_TIMEOUT-2))
  if [ $APP_TIMEOUT -le 0 ]; then
    echo "Erro: app não ficou saudável a tempo." >&2
    exit 1
  fi
done
echo "✅ App saudável."

echo "Executando migrações..."
if ! docker compose -f docker-compose.preview.yml -p "${SERVICE_NAME}" exec -T app php artisan migrate --force; then
  echo "Migrações falharam, tentando novamente em 5s..."
  sleep 5
  docker compose -f docker-compose.preview.yml -p "${SERVICE_NAME}" exec -T app php artisan migrate --force
fi
echo "✅ Migrações concluídas."

echo "Verificando readiness HTTP de https://${HOSTNAME}/health ..."
READY_TIMEOUT=120
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

echo "🎉 Deploy da PR #${PR_NUMBER} concluído com sucesso!"
