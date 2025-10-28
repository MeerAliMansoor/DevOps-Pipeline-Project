#!/bin/bash
set -e  # Exit immediately if any command fails

# =========================
# Deployment Script (Backend + Frontend)
# =========================
TIMESTAMP=$(date +%F-%T)
echo "🕒 Deployment started at $TIMESTAMP"

# Base directories
DEPLOY_BASE="/home/meerali/devops/devops-deploy"
BACKEND_DIR="$DEPLOY_BASE/backend"
FRONTEND_DIR="$DEPLOY_BASE/frontend"
BACKUP_DIR="$DEPLOY_BASE/backup"

# =========================
# Backup current deployments
# =========================
echo "💾 Backing up current deployments..."
mkdir -p "$BACKUP_DIR"

if [ -d "$BACKEND_DIR/dist" ]; then
    tar -czf "$BACKUP_DIR/backend-$TIMESTAMP.tar.gz" -C "$BACKEND_DIR/dist" .
    echo "✅ Backend backup completed."
else
    echo "⚠️ No backend found to back up."
fi

if [ -d "$FRONTEND_DIR/build" ]; then
    tar -czf "$BACKUP_DIR/frontend-$TIMESTAMP.tar.gz" -C "$FRONTEND_DIR/build" .
    echo "✅ Frontend backup completed."
else
    echo "⚠️ No frontend found to back up."
fi

# =========================
# Deploy Backend
# =========================
echo "🚀 Deploying backend..."
cd "$BACKEND_DIR" || { echo "❌ Backend directory not found!"; exit 1; }

echo "📦 Installing dependencies..."
npm install --production

echo "🏗️ Building backend..."
npm run build

echo "🔁 Restarting backend with PM2..."
pm2 delete backend-app || true
pm2 start dist/main.js --name backend-app --interpreter node
pm2 save

echo "✅ Backend deployed successfully."

# =========================
# Deploy Frontend
# =========================
echo "🚀 Deploying frontend..."
cd "$FRONTEND_DIR" || { echo "❌ Frontend directory not found!"; exit 1; }

echo "📦 Installing dependencies..."
npm install --production

echo "🏗️ Building frontend..."
npm run build

echo "🌐 Serving frontend..."
pm2 delete react-frontend || true
pm2 start npx --name react-frontend -- serve -s build -l 3000
pm2 save

echo "✅ Frontend deployed successfully."

echo "🎉 Deployment completed successfully at $TIMESTAMP!"

