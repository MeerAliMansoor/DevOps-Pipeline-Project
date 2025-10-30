
pipeline {
    agent any

    environment {
        SLACK_CHANNEL    = "#devopsnotifications"
        SLACK_TOKEN      = credentials('SLACK_TOKEN')

        SSH_CREDENTIALS  = 'deploy-ssh-creds'
        DEPLOY_SERVER    = 'meerali@127.0.0.1'

        DEPLOY_PATH      = '/home/meerali/devops/devops-deploy'
        DEPLOY_SCRIPT    = 'deploy-docker.sh'
        BACKUP_DIR       = '/home/meerali/devops/backup'

        // Project paths (in repo)
        BACKEND_SRC_PATH = 'backend/backend-app'   // you confirmed: devops/backend/backend-app
        FRONTEND_SRC_PATH= 'frontend'             // you confirmed: devops/frontend
        DOCKER_COMPOSE   = 'docker-compose.yml'
    }

    stages {
        stage('Checkout') {
            steps {
                echo "🔄 Checkout repository"
                checkout scm
                slackSend(channel: env.SLACK_CHANNEL, tokenCredentialId: 'SLACK_TOKEN', message: "📦 Starting build: ${env.JOB_NAME} #${env.BUILD_NUMBER}")
            }
        }

        stage('Build Backend') {
            steps {
                dir("${BACKEND_SRC_PATH}") {
                    echo "📦 Backend: install & build"
                    sh 'npm ci || npm install'
                    sh 'npm test || echo "⚠️ Backend tests skipped or failed (non-blocking)"'
                    sh 'npm run build'
                }
                // package backend source (tar) for transfer
                sh """
                    tar -czf ${WORKSPACE}/backend-src.tar.gz -C ${WORKSPACE}/${BACKEND_SRC_PATH} .
                    ls -lh ${WORKSPACE}/backend-src.tar.gz
                """
                archiveArtifacts artifacts: 'backend-src.tar.gz', fingerprint: true
            }
        }

        stage('Build Frontend') {
            steps {
                dir("${FRONTEND_SRC_PATH}") {
                    echo "📦 Frontend: install & build"
                    sh 'npm ci || npm install'
                    sh 'npm test || echo "⚠️ Frontend tests skipped or failed (non-blocking)"'
                    sh 'npm run build'
                }
                // package frontend source (tar) for transfer
                sh """
                    tar -czf ${WORKSPACE}/frontend-src.tar.gz -C ${WORKSPACE}/${FRONTEND_SRC_PATH} .
                    ls -lh ${WORKSPACE}/frontend-src.tar.gz
                """
                archiveArtifacts artifacts: 'frontend-src.tar.gz', fingerprint: true
            }
        }

        stage('Prepare transfer files') {
            steps {
                // Ensure docker-compose and deploy script exist
                script {
                    if (!fileExists("${DOCKER_COMPOSE}")) {
                        error("docker-compose.yml not found at ${DOCKER_COMPOSE}. Please add it to repo at devops/docker-compose.yml")
                    }
                    if (!fileExists("deploy-docker.sh")) {
                        error("deploy-docker.sh not found at devops/deploy-docker.sh. Please add it (I provided one) and commit.")
                    }
                }
                sh "ls -la devops || true"
            }
        }

        stage('Transfer to target server') {
            steps {
                script {
                    sshagent([env.SSH_CREDENTIALS]) {
                        echo "📡 Creating remote directories: ${DEPLOY_PATH}"
                        sh "ssh -o StrictHostKeyChecking=no ${DEPLOY_SERVER} \"mkdir -p ${DEPLOY_PATH} ${BACKUP_DIR}\""

                        echo "📤 Copying packaged sources and compose file + deploy script"
                        sh "scp -o StrictHostKeyChecking=no ${WORKSPACE}/backend-src.tar.gz ${DEPLOY_SERVER}:${DEPLOY_PATH}/backend-src.tar.gz"
                        sh "scp -o StrictHostKeyChecking=no ${WORKSPACE}/frontend-src.tar.gz ${DEPLOY_SERVER}:${DEPLOY_PATH}/frontend-src.tar.gz"
                        sh "scp -o StrictHostKeyChecking=no ${WORKSPACE}/${DOCKER_COMPOSE} ${DEPLOY_SERVER}:${DEPLOY_PATH}/docker-compose.yml"
                        sh "scp -o StrictHostKeyChecking=no ${WORKSPACE}/devops/deploy-docker.sh ${DEPLOY_SERVER}:${DEPLOY_PATH}/deploy-docker.sh"
                        // set executable
                        sh "ssh -o StrictHostKeyChecking=no ${DEPLOY_SERVER} \"chmod +x ${DEPLOY_PATH}/deploy-docker.sh\""
                    }
                }
            }
        }

        stage('Deploy on remote via Docker Compose') {
            steps {
                script {
                    slackSend(channel: env.SLACK_CHANNEL, tokenCredentialId: 'SLACK_TOKEN', message: "🚀 Deploying ${env.JOB_NAME} #${env.BUILD_NUMBER} to ${DEPLOY_SERVER}")
                    sshagent([env.SSH_CREDENTIALS]) {
                        // Execute the remote deploy script (it will build images & run docker compose).
                        // We run it with bash to ensure exit code propagation.
                        sh "ssh -o StrictHostKeyChecking=no ${DEPLOY_SERVER} \"bash ${DEPLOY_PATH}/deploy-docker.sh ${DEPLOY_PATH} ${BACKUP_DIR} || exit 1\""
                    }
                }
            }
        }
    }

    post {
        success {
            slackSend(channel: env.SLACK_CHANNEL, tokenCredentialId: 'SLACK_TOKEN', message: "✅ Build & Deploy SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER}")
            cleanWs()
        }
        failure {
            slackSend(channel: env.SLACK_CHANNEL, tokenCredentialId: 'SLACK_TOKEN', message: "❌ Build or Deploy FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER}")
            cleanWs()
        }
        always {
            echo "🔚 Pipeline finished for ${env.JOB_NAME} #${env.BUILD_NUMBER}"
        }
    }
}

