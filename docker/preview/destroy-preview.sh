#!/bin/bash
set -euo pipefail

: "${PR_NUMBER:?A variável PR_NUMBER não foi definida.}"
: "${PROJECT_DIR:?A variável PROJECT_DIR não foi definida.}"
: "${PROJECT_NAME:?A variável PROJECT_NAME não foi definida.}"

SERVICE_NAME="${PROJECT_NAME}-pr-${PR_NUMBER}"

echo "Iniciando destruição do ambiente da PR #${PR_NUMBER}..."

if [ ! -d "$PROJECT_DIR" ]; then
  echo "Diretório do projeto ${PROJECT_DIR} não encontrado. Nada a fazer."
  exit 0
fi

cd "${PROJECT_DIR}"

echo "--- Estado antes da remoção ---"
docker compose -f docker-compose.preview.yml -p "${SERVICE_NAME}" ps -a || true

echo "--- Logs finais (últimos 200) ---"
docker compose -f docker-compose.preview.yml -p "${SERVICE_NAME}" logs --no-color --tail=200 || true

echo "Derrubando stack e removendo volumes..."
docker compose -f docker-compose.preview.yml -p "${SERVICE_NAME}" down -v --remove-orphans || true

echo "Removendo diretório do projeto..."
cd ..
rm -rf "${PROJECT_DIR}"

echo "Removendo imagens Docker com label da PR no servidor..."
IMAGES_TO_DELETE=$(docker images -q --filter "label=br.com.carlosalexandre.preview.pr=${PR_NUMBER}")
if [ -n "$IMAGES_TO_DELETE" ]; then
  docker rmi $IMAGES_TO_DELETE || true
else
  echo "Nenhuma imagem com a label da PR encontrada."
fi

echo "Limpando imagens dangling e cache local..."
docker image prune -f || true
docker builder prune -f || true

echo "Removendo networks do projeto..."
for NET in $(docker network ls --format '{{.Name}}' | grep "^${SERVICE_NAME}"); do
  if [ "$NET" != "proxy" ]; then
    docker network rm "$NET" || true
  fi
done

echo "✅ Ambiente da PR #${PR_NUMBER} destruído com sucesso."
