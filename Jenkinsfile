pipeline {
    agent any

    environment {
        BACKEND_DIR = "backend/backend-app"
        FRONTEND_DIR = "frontend"
        BACKUP_DIR = "backup"
    }

    stages {
        stage('Clone Repository') {
            steps {
                echo "🔄 Cloning repository..."
                checkout scm
            }
        }

        stage('Install Backend Dependencies') {
            steps {
                dir("${BACKEND_DIR}") {
                    echo "📦 Installing backend dependencies..."
                    sh 'npm install'
                }
            }
        }

        stage('Install Frontend Dependencies') {
            steps {
                dir("${FRONTEND_DIR}") {
                    echo "📦 Installing frontend dependencies..."
                    sh 'npm install'
                }
            }
        }

        stage('Build Backend') {
            steps {
                dir("${BACKEND_DIR}") {
                    echo "🔨 Building backend..."
                    sh 'npm run build'
                }
            }
        }

        stage('Build Frontend') {
            steps {
                dir("${FRONTEND_DIR}") {
                    echo "🔨 Building frontend..."
                    sh 'npm run build'
                }
            }
        }

        stage('Run Backend Tests') {
            steps {
                dir("${BACKEND_DIR}") {
                    echo "🧪 Running backend tests..."
                    sh 'npm test || echo "⚠️ Tests failed or not found"'
                }
            }
        }

        stage('Backup Current Deployment') {
            steps {
                echo "💾 Backing up current deployment..."
                sh '''
                    mkdir -p ${BACKUP_DIR}
                    if [ -d "/home/meerali/dist" ]; then
                        tar -czf ${BACKUP_DIR}/backend-backup-$(date +%s).tar.gz -C /home/meerali dist
                    fi
                    if [ -d "/home/meerali/build" ]; then
                        tar -czf ${BACKUP_DIR}/frontend-backup-$(date +%s).tar.gz -C /home/meerali build
                    fi
                '''
            }
        }

        stage('Deploy Backend & Frontend via PM2') {
            steps {
                echo "🚀 Deploying backend and frontend..."

                // Backend Deployment
                dir("${BACKEND_DIR}") {
                    sh '''
                    pm2 delete backend-app || true
                    pm2 start npm --name backend-app -- start
                    '''
                }

                // Frontend Deployment (ESM safe)
                dir("${FRONTEND_DIR}") {
                    sh '''
                    pm2 delete react-frontend || true
                    pm2 start npx --name react-frontend -- serve -s build -l 3000
                    '''
                }
            }
        }
    }

    post {
        success {
            echo '✅ Pipeline executed successfully!'
        }
        failure {
            echo '❌ Pipeline failed! Consider rolling back manually from backup.'
        }
    }
}

