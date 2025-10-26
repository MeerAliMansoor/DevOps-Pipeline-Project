#!/usr/bin/env bash
set -euo pipefail

# Arguments
BACKEND_TAR="$1"
FRONTEND_TAR="$2"
DEPLOY_PATH="/home/meerali"
BACKUP_DIR="${DEPLOY_PATH}/backup"
TIMESTAMP=$(date +%F-%T)

echo "=== remote_deploy.sh ==="
echo "backend tar: $BACKEND_TAR"
echo "frontend tar: $FRONTEND_TAR"
echo "deploy path: $DEPLOY_PATH"

mkdir -p "${BACKUP_DIR}"

# BACKUP existing
if [ -d "${DEPLOY_PATH}/dist" ]; then
  echo "Backing up current backend..."
  tar -czf "${BACKUP_DIR}/backend-${TIMESTAMP}.tar.gz" -C "${DEPLOY_PATH}" dist
fi

if [ -d "${DEPLOY_PATH}/build" ]; then
  echo "Backing up current frontend..."
  tar -czf "${BACKUP_DIR}/frontend-${TIMESTAMP}.tar.gz" -C "${DEPLOY_PATH}" build
fi

# EXTRACT new backend artifact -> /home/meerali/dist
echo "Deploying backend..."
rm -rf "${DEPLOY_PATH}/dist"
mkdir -p "${DEPLOY_PATH}/dist"
tar -xzf "${DEPLOY_PATH}/${BACKEND_TAR}" -C "${DEPLOY_PATH}/dist"

# install production dependencies (if package.json exists inside backend project folder)
if [ -f "${DEPLOY_PATH}/dist/package.json" ]; then
  echo "Installing production dependencies for backend..."
  pushd "${DEPLOY_PATH}/dist" >/dev/null
  npm install --production || echo "npm install --production failed"
  popd >/dev/null
fi

# Start/restart backend using PM2 (run built JS)
if [ -f "${DEPLOY_PATH}/dist/main.js" ]; then
  pm2 delete backend-app || true
  pm2 start "${DEPLOY_PATH}/dist/main.js" --name backend-app || { echo "PM2 failed to start backend"; exit 1; }
else
  echo "Error: dist/main.js not found after extracting backend artifact"; exit 1
fi

# EXTRACT new frontend artifact -> /home/meerali/build
echo "Deploying frontend..."
rm -rf "${DEPLOY_PATH}/build"
mkdir -p "${DEPLOY_PATH}/build"
tar -xzf "${DEPLOY_PATH}/${FRONTEND_TAR}" -C "${DEPLOY_PATH}/build"

# Serve static with pm2 built-in serve
pm2 delete react-frontend || true
pm2 serve "${DEPLOY_PATH}/build" 3000 --name react-frontend --spa || { echo "PM2 failed to start frontend"; exit 1; }

# Save pm2 list so it auto-restores on reboot
pm2 save

echo "Deployment finished successfully: $(date)"

