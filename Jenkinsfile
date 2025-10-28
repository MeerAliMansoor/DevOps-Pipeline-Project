pipeline {
    agent any

    environment {
        SLACK_CHANNEL = "#devopsnotifications"
        SLACK_TOKEN = credentials('SLACK_TOKEN')

        SSH_CREDENTIALS = 'deploy-ssh-creds'
        DEPLOY_SERVER = 'meerali@127.0.0.1'

        DEPLOY_PATH = '/home/meerali/devops/devops-deploy'
        DEPLOY_SCRIPT = '/home/meerali/devops/deploy.sh'
        BACKUP_DIR = '/home/meerali/devops/backup'
    }

    stages {

        stage('Checkout') {
            steps {
                slackSend(channel: env.SLACK_CHANNEL, message: "📦 Starting build for *${env.JOB_NAME}* #${env.BUILD_NUMBER}")
                checkout scm
            }
        }

        stage('Build Backend') {
            steps {
                dir('backend/backend-app') {
                    sh 'npm install'
                    sh 'npm run build'
                    stash includes: 'dist/**', name: 'backend'
                }
            }
        }

        stage('Build Frontend') {
            steps {
                dir('frontend') {
                    sh 'npm install'
                    sh 'npm run build'
                    stash includes: 'build/**', name: 'frontend'
                }
            }
        }

        stage('Transfer Files to Server') {
            steps {
                script {
                    sshagent([env.SSH_CREDENTIALS]) {
                        sh """ssh -o StrictHostKeyChecking=no ${DEPLOY_SERVER} "mkdir -p ${DEPLOY_PATH}/backend ${DEPLOY_PATH}/frontend" """
                        unstash 'backend'
                        unstash 'frontend'
                        sh """scp -r backend/backend-app/dist/* ${DEPLOY_SERVER}:${DEPLOY_PATH}/backend/"""
                        sh """scp -r frontend/build/* ${DEPLOY_SERVER}:${DEPLOY_PATH}/frontend/"""
                    }
                }
            }
        }

        stage('Deploy via SSH') {
            steps {
                script {
                    slackSend(channel: env.SLACK_CHANNEL, message: "🚀 Deploying *${env.JOB_NAME}* #${env.BUILD_NUMBER}...")

                    try {
                        sshagent([env.SSH_CREDENTIALS]) {
                            sh """ssh -o StrictHostKeyChecking=no ${DEPLOY_SERVER} "bash ${DEPLOY_SCRIPT}" """
                        }

                        slackSend(channel: env.SLACK_CHANNEL, message: "✅ Deployment successful for *${env.JOB_NAME}* #${env.BUILD_NUMBER}")
                    } catch (err) {
                        slackSend(channel: env.SLACK_CHANNEL, message: "❌ Deployment failed! Checking for backups...")

                        sshagent([env.SSH_CREDENTIALS]) {
                            sh """ssh -o StrictHostKeyChecking=no ${DEPLOY_SERVER} '
                                LATEST_BE_BACKUP=\$(ls -t ${BACKUP_DIR}/backend-*.tar.gz 2>/dev/null | head -n1)
                                if [ -f "\$LATEST_BE_BACKUP" ]; then
                                    tar -xzf "\$LATEST_BE_BACKUP" -C ${DEPLOY_PATH}/backend && echo "✅ Backend rollback complete"
                                else
                                    echo "⚠️ No backend backup found. Skipping rollback."
                                fi

                                LATEST_FE_BACKUP=\$(ls -t ${BACKUP_DIR}/frontend-*.tar.gz 2>/dev/null | head -n1)
                                if [ -f "\$LATEST_FE_BACKUP" ]; then
                                    tar -xzf "\$LATEST_FE_BACKUP" -C ${DEPLOY_PATH}/frontend && echo "✅ Frontend rollback complete"
                                else
                                    echo "⚠️ No frontend backup found. Skipping rollback."
                                fi
                            '"""
                        }

                        error("Deployment failed. Rollback attempted if backups existed.")
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

