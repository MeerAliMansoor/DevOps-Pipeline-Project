pipeline {
    agent any

    environment {
        SLACK_CHANNEL = "#devopsnotifications"
        SLACK_TOKEN = credentials('SLACK_TOKEN')

        SSH_CREDENTIALS = 'deploy-ssh-creds'
        DEPLOY_SERVER = 'meerali@127.0.0.1'

        DEPLOY_PATH = '/home/meerali/devops/devops-deploy'
        BACKUP_DIR = '/home/meerali/devops/backup'

        BACKEND_IMAGE = 'backend-app:latest'
        FRONTEND_IMAGE = 'frontend-app:latest'
        BACKEND_CONTAINER = 'backend-container'
        FRONTEND_CONTAINER = 'frontend-container'
    }

    stages {
        stage('Checkout') {
            steps {
                slackSend(channel: env.SLACK_CHANNEL, message: "📦 Starting Docker build for *${env.JOB_NAME}* #${env.BUILD_NUMBER}")
                checkout scm
            }
        }

        stage('Build Backend Docker Image') {
            steps {
                dir('backend/backend-app') {
                    sh 'docker build -t $BACKEND_IMAGE .'
                }
            }
        }

        stage('Build Frontend Docker Image') {
            steps {
                dir('frontend') {
                    sh 'docker build -t $FRONTEND_IMAGE .'
                }
            }
        }

        stage('Deploy via SSH & Docker') {
            steps {
                script {
                    slackSend(channel: env.SLACK_CHANNEL, message: "🚀 Deploying *${env.JOB_NAME}* #${env.BUILD_NUMBER} via Docker...")

                    try {
                        sshagent([env.SSH_CREDENTIALS]) {
                            sh """
                            ssh -o StrictHostKeyChecking=no ${DEPLOY_SERVER} '
                                echo "🧹 Cleaning up old containers..."
                                docker stop ${BACKEND_CONTAINER} || true &&
                                docker rm ${BACKEND_CONTAINER} || true &&
                                docker stop ${FRONTEND_CONTAINER} || true &&
                                docker rm ${FRONTEND_CONTAINER} || true &&

                                echo "📦 Running new backend container..."
                                docker run -d --name ${BACKEND_CONTAINER} -p 5000:5000 ${BACKEND_IMAGE} &&

                                echo "🌐 Running new frontend container..."
                                docker run -d --name ${FRONTEND_CONTAINER} -p 3000:3000 ${FRONTEND_IMAGE}
                            '
                            """
                        }

                        slackSend(channel: env.SLACK_CHANNEL, message: "✅ Deployment successful for *${env.JOB_NAME}* #${env.BUILD_NUMBER}")

                    } catch (err) {
                        slackSend(channel: env.SLACK_CHANNEL, message: "❌ Deployment failed! Attempting rollback...")

                        sshagent([env.SSH_CREDENTIALS]) {
                            sh """
                            ssh -o StrictHostKeyChecking=no ${DEPLOY_SERVER} '
                                echo "🔙 Rolling back to previous Docker containers..."
                                docker stop ${BACKEND_CONTAINER} || true &&
                                docker rm ${BACKEND_CONTAINER} || true &&
                                docker stop ${FRONTEND_CONTAINER} || true &&
                                docker rm ${FRONTEND_CONTAINER} || true &&

                                # Optional: Start previous versions if tagged properly
                                echo "♻️ Starting last known stable images (if exist)..."
                                docker run -d --name ${BACKEND_CONTAINER} -p 5000:5000 ${BACKEND_IMAGE} ||
                                echo "⚠️ No previous backend image found" &&
                                docker run -d --name ${FRONTEND_CONTAINER} -p 3000:3000 ${FRONTEND_IMAGE} ||
                                echo "⚠️ No previous frontend image found"
                            '
                            """
                        }

                        error("Deployment failed. Rollback attempted if images existed.")
                    }
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }

        failure {
            slackSend(channel: env.SLACK_CHANNEL, message: "🔴 Build failed for *${env.JOB_NAME}* #${env.BUILD_NUMBER}")
        }

        success {
            slackSend(channel: env.SLACK_CHANNEL, message: "🟢 Build passed for *${env.JOB_NAME}* #${env.BUILD_NUMBER}")
        }
    }
}

