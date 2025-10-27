pipeline {
    agent any

    environment {
        // Slack credentials and channel
        SLACK_CHANNEL = "#devopsnotifications"
        SLACK_TOKEN = credentials('SLACK_TOKEN')

        // SSH credentials and server details
        SSH_CREDENTIALS = 'ssh-server-creds'
        DEPLOY_SERVER = 'meerali@127.0.0'

        // Deployment paths
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
                dir('backend') {
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
                        sh """
                            ssh -o StrictHostKeyChecking=no ${DEPLOY_SERVER} 'mkdir -p ${DEPLOY_PATH}/backend ${DEPLOY_PATH}/frontend'
                        """
                        unstash 'backend'
                        unstash 'frontend'

                        // Copy both builds to remote server
                        sh """
                            scp -r backend/dist/* ${DEPLOY_SERVER}:${DEPLOY_PATH}/backend/
                            scp -r frontend/build/* ${DEPLOY_SERVER}:${DEPLOY_PATH}/frontend/
                        """
                    }
                }
            }
        }

        stage('Deploy via SSH') {
            steps {
                script {
                    slackSend(channel: env.SLACK_CHANNEL, message: "🚀 Deploying *${env.JOB_NAME}* #${env.BUILD_NUMBER} to production...")

                    try {
                        sshagent([env.SSH_CREDENTIALS]) {
                            sh """
                                ssh -o StrictHostKeyChecking=no ${DEPLOY_SERVER} '
                                echo "🔁 Running deployment script..." &&
                                bash ${DEPLOY_SCRIPT}
                                '
                            """
                        }

                        slackSend(channel: env.SLACK_CHANNEL, message: "✅ *Deployment successful!* for *${env.JOB_NAME}* #${env.BUILD_NUMBER}")
                    } catch (err) {
                        slackSend(channel: env.SLACK_CHANNEL, message: "❌ *Deployment failed!* Rolling back to previous version...")

                        sshagent([env.SSH_CREDENTIALS]) {
                            sh """
                                ssh -o StrictHostKeyChecking=no ${DEPLOY_SERVER} '
                                echo "🔄 Rolling back deployment..." &&
                                LATEST_BACKUP=$(ls -t ${BACKUP_DIR}/backend-*.tar.gz | head -n1) &&
                                if [ -f "$LATEST_BACKUP" ]; then
                                    tar -xzf "$LATEST_BACKUP" -C /home/meerali/dist
                                    echo "✅ Rollback complete for backend."
                                fi
                                
                                LATEST_FE_BACKUP=$(ls -t ${BACKUP_DIR}/frontend-*.tar.gz | head -n1) &&
                                if [ -f "$LATEST_FE_BACKUP" ]; then
                                    tar -xzf "$LATEST_FE_BACKUP" -C /home/meerali/build
                                    echo "✅ Rollback complete for frontend."
                                fi
                                '
                            """
                        }

                        error("Deployment failed and rollback executed.")
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

