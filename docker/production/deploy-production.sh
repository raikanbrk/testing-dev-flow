#!/bin/bash
set -euo pipefail

: "${IMAGE_TAG:?A variável IMAGE_TAG não foi definida.}"
: "${COMMIT_SHA:?A variável COMMIT_SHA não foi definida.}"
: "${PROJECT_DIR:?A variável PROJECT_DIR não foi definida.}"

export HOSTNAME="testing-dev-flow.carlosalexandre.com.br"
export ROUTER_NAME="testing-dev-flow"
export COMPOSE_FILE="docker-compose.production.yml"

trap 'echo "--- [ERRO] O deploy falhou. Coletando informações para debug... ---"; docker compose -f ${COMPOSE_FILE} -p ${SERVICE_NAME} ps || true; echo "--- Logs (últimas 200 linhas) ---"; docker compose -f ${COMPOSE_FILE} -p ${SERVICE_NAME} logs --no-color --tail=200 || true' ERR

echo "🚀 Iniciando deploy de produção para o commit ${COMMIT_SHA}..."
echo "-> Imagem: devc4rlos/testing-dev-flow:${IMAGE_TAG}"

cd "${PROJECT_DIR}"

if [ ! -f .env ]; then
    echo "❌ Erro Crítico: O arquivo .env não foi encontrado em ${PROJECT_DIR}."
    echo "   Por segurança, o .env de produção deve ser criado manualmente no servidor."
    exit 1
fi

echo "🔄 Atualizando o código-fonte (ex: docker-compose.yml)..."
git fetch origin
git checkout "${COMMIT_SHA}"

docker compose -f "${COMPOSE_FILE}" -p "${SERVICE_NAME}" down -v

echo "⬆️  Atualizando os serviços com Docker Compose..."
docker compose -f "${COMPOSE_FILE}" -p "${SERVICE_NAME}" up -d --remove-orphans

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


echo "📡 Verificando se a aplicação está respondendo via HTTP..."
READY_TIMEOUT=60
while true; do
  HTTP_CODE=$(curl --insecure --silent --output /dev/null --write-out "%{http_code}" \
                   --max-time 5 \
                   --resolve "${HOSTNAME}:443:127.0.0.1" \
                   "https://${HOSTNAME}/" || true)

  case "$HTTP_CODE" in
    200|301|302)
      echo "✅ Aplicação respondendo com sucesso (código ${HTTP_CODE}) em https://${HOSTNAME} (via localhost)."
      break
      ;;
    *)
      echo "Aguardando resposta HTTP... (último código: ${HTTP_CODE})"
      sleep 3
      READY_TIMEOUT=$((READY_TIMEOUT-3))
      if [ $READY_TIMEOUT -le 0 ]; then
        echo "❌ Erro: Verificação HTTP falhou. Último código recebido: ${HTTP_CODE}" >&2
        exit 1
      fi
      ;;
  esac
done

echo "🧹 Limpando imagens Docker antigas..."
docker image prune -af

echo "🎉 Deploy em produção concluído com sucesso!"
