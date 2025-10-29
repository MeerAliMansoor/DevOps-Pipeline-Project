#!/usr/bin/env bash
set -euo pipefail

# Usage: deploy-docker.sh <DEPLOY_PATH> <BACKUP_DIR>
DEPLOY_PATH="${1:-/home/meerali/devops/devops-deploy}"
BACKUP_DIR="${2:-/home/meerali/devops/backup}"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"

echo "🕒 [deploy-docker] Starting at $(date -u) -- DEPLOY_PATH=${DEPLOY_PATH}"

# ensure required dirs
mkdir -p "${DEPLOY_PATH}"
mkdir -p "${BACKUP_DIR}"

cd "${DEPLOY_PATH}"

# 1) backup running containers by committing them to images (simple fallback)
echo "💾 Backing up current containers (if any) by committing images..."
# commit if containers exist (names used below must match docker-compose service names)
if docker ps --format '{{.Names}}' | grep -q '^backend-app$'; then
  docker commit backend-app backend-app:backup-${TIMESTAMP} || true
  echo "✅ Backed up backend-app -> backend-app:backup-${TIMESTAMP}"
fi

if docker ps --format '{{.Names}}' | grep -q '^frontend-app$'; then
  docker commit frontend-app frontend-app:backup-${TIMESTAMP} || true
  echo "✅ Backed up frontend-app -> frontend-app:backup-${TIMESTAMP}"
fi

# 2) extract uploaded archives into deploy path (overwrite)
echo "📦 Extracting uploaded backend and frontend archives (if present)..."
if [ -f "${DEPLOY_PATH}/backend-src.tar.gz" ]; then
    rm -rf "${DEPLOY_PATH}/backend" || true
    mkdir -p "${DEPLOY_PATH}/backend"
    tar -xzf "${DEPLOY_PATH}/backend-src.tar.gz" -C "${DEPLOY_PATH}/backend"
    echo "✅ backend extracted to ${DEPLOY_PATH}/backend"
fi

if [ -f "${DEPLOY_PATH}/frontend-src.tar.gz" ]; then
    rm -rf "${DEPLOY_PATH}/frontend" || true
    mkdir -p "${DEPLOY_PATH}/frontend"
    tar -xzf "${DEPLOY_PATH}/frontend-src.tar.gz" -C "${DEPLOY_PATH}/frontend"
    echo "✅ frontend extracted to ${DEPLOY_PATH}/frontend"
fi

# 3) run docker compose: build & up
echo "🐳 Running docker compose (build & up - detached)..."

# If compose v2 plugin exists use "docker compose", otherwise fallback to "docker-compose"
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    echo "❌ docker compose not found on remote. Install docker compose or docker-compose plugin."
    exit 2
fi

# Ensure docker daemon is reachable
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker daemon not reachable. Ensure docker is running and this user can access docker socket."
    exit 3
fi

# Save previous images list (optional)
PREV_IMAGES_FILE="${BACKUP_DIR}/images-${TIMESTAMP}.txt"
docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' > "${PREV_IMAGES_FILE}" || true

# Try an atomic deploy: build then bring up, with trap to attempt rollback on failure
set +e
${COMPOSE_CMD} -f "${DEPLOY_PATH}/docker-compose.yml" build --pull
BUILD_EXIT=$?
if [ $BUILD_EXIT -ne 0 ]; then
    echo "❌ docker compose build failed (exit=$BUILD_EXIT). Trying to rollback to last backup images..."
    # no further automated action here (fallback below)
    set -e
    exit 4
fi

${COMPOSE_CMD} -f "${DEPLOY_PATH}/docker-compose.yml" up -d --remove-orphans --force-recreate
UP_EXIT=$?
set -e

if [ $UP_EXIT -ne 0 ]; then
    echo "❌ docker compose up failed (exit=$UP_EXIT). Attempting to rollback to committed backup images..."
    # Try to stop current (failed) containers
    ${COMPOSE_CMD} -f "${DEPLOY_PATH}/docker-compose.yml" down || true

    # Try to start backup images if they exist
    if docker image inspect backend-app:backup-${TIMESTAMP} >/dev/null 2>&1; then
        docker run -d --name backend-app -p 5000:5000 backend-app:backup-${TIMESTAMP} || true
        echo "♻️ restored backend-app from backup image"
    fi
    if docker image inspect frontend-app:backup-${TIMESTAMP} >/dev/null 2>&1; then
        docker run -d --name frontend-app -p 3000:3000 frontend-app:backup-${TIMESTAMP} || true
        echo "♻️ restored frontend-app from backup image"
    fi

    exit 5
fi

echo "✅ Deploy succeeded. Saving image backups metadata to ${BACKUP_DIR}"
echo "${TIMESTAMP}" > "${BACKUP_DIR}/last_deploy_timestamp.txt"
echo "OK" > "${BACKUP_DIR}/last_deploy_status.txt"

# Optional: prune unused images (disabled by default)
# docker image prune -f

echo "🎉 Docker Compose deployment completed successfully."
exit 0

