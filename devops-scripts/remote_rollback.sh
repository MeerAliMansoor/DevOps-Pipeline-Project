#!/usr/bin/env bash
set -euo pipefail

DEPLOY_PATH="/home/meerali"
BACKUP_DIR="${DEPLOY_PATH}/backup"

echo "=== remote_rollback.sh ==="
echo "Looking for latest backups in ${BACKUP_DIR}"

LATEST_BACKEND=$(ls -1t ${BACKUP_DIR}/backend-*.tar.gz 2>/dev/null | head -n1 || true)
LATEST_FRONTEND=$(ls -1t ${BACKUP_DIR}/frontend-*.tar.gz 2>/dev/null | head -n1 || true)

if [ -n "$LATEST_BACKEND" ]; then
  echo "Restoring backend from $LATEST_BACKEND"
  rm -rf "${DEPLOY_PATH}/dist"
  mkdir -p "${DEPLOY_PATH}/dist"
  tar -xzf "$LATEST_BACKEND" -C "${DEPLOY_PATH}/dist"
  pm2 restart backend-app || pm2 start "${DEPLOY_PATH}/dist/main.js" --name backend-app
else
  echo "No backend backup found to restore"
fi

if [ -n "$LATEST_FRONTEND" ]; then
  echo "Restoring frontend from $LATEST_FRONTEND"
  rm -rf "${DEPLOY_PATH}/build"
  mkdir -p "${DEPLOY_PATH}/build"
  tar -xzf "$LATEST_FRONTEND" -C "${DEPLOY_PATH}/build"
  pm2 restart react-frontend || pm2 serve "${DEPLOY_PATH}/build" 3000 --name react-frontend --spa
else
  echo "No frontend backup found to restore"
fi

pm2 save
echo "Rollback completed."

