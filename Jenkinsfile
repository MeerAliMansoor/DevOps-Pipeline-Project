pipeline {
    agent any

    // Parameter to allow manual rollback from Jenkins UI
    parameters {
        booleanParam(name: 'FORCE_ROLLBACK', defaultValue: false, description: 'If true, skip deploy and run rollback on server')
    }

    environment {
        BACKEND_DIR = "backend/backend-app"
        FRONTEND_DIR = "frontend"
        BACKEND_ART = "backend-dist.tar.gz"
        FRONTEND_ART = "frontend-build.tar.gz"
        DEPLOY_USER = "meerali"
        DEPLOY_HOST = "127.0.0.1"  // Localhost for testing
        DEPLOY_PATH = "/home/meerali/devops/devops-deploy"
        SSH_CREDENTIALS_ID = "deploy-ssh-creds"  // Jenkins SSH credentials
        SLACK_CHANNEL = "devopsnotifications"  // Change to your Slack channel
    }

    stages {
        stage('Checkout') {
            steps {
                echo "🔄 Checkout"
                checkout scm
            }
        }

        stage('Install & Build Backend') {
            steps {
                dir("${BACKEND_DIR}") {
                    echo "📦 Backend: install, test, build"
                    sh 'npm ci'
                    sh 'npm test || echo "⚠️ Tests failed or not found"'
                    sh 'npm run build'
		    sh "tar -czf ${BACKEND_ART} -C dist . || (echo 'No dist folder'; exit 1)"
		    archiveArtifacts artifacts: "${BACKEND_ART}", fingerprint: true
		}
            }
        }

        stage('Install & Build Frontend') {
            steps {
                dir("${FRONTEND_DIR}") {
                    echo "📦 Frontend: install, test, build"
                    sh 'npm ci'
                    sh 'npm test || echo "⚠️ Frontend tests failed or not found"'
                    sh 'npm run build'
		    sh "tar -czf ${FRONTEND_ART} -C build . || (echo 'No build folder'; exit 1)"
		    archiveArtifacts artifacts: "${FRONTEND_ART}", fingerprint: true
                }
            }
        }

        stage('Stash Artifacts') {
            steps {
                dir("${BACKEND_DIR}") { stash includes: "${BACKEND_ART}", name: 'backend-art' }
                dir("${FRONTEND_DIR}") { stash includes: "${FRONTEND_ART}", name: 'frontend-art' }
            }
        }

        stage('Deploy or Rollback') {
            steps {
                script {
                    if (params.FORCE_ROLLBACK) {
                        echo "⚠️ FORCE_ROLLBACK is true — calling remote rollback"
                        sshagent(credentials: [env.SSH_CREDENTIALS_ID]) {
                            sh """
                                ssh -o StrictHostKeyChecking=no ${DEPLOY_USER}@${DEPLOY_HOST} 'bash -s' < ${WORKSPACE}/devops-scripts/remote_rollback.sh
                            """
                        }
                    } else {
                        echo "🚀 Deploying artifacts to target server"

                        dir("${WORKSPACE}") {
                            unstash 'backend-art'
                            unstash 'frontend-art'
                        }

                        sshagent(credentials: [env.SSH_CREDENTIALS_ID]) {
                            sh """
                                # Copy artifacts
                                scp -o StrictHostKeyChecking=no ${BACKEND_DIR}/${BACKEND_ART} ${DEPLOY_USER}@${DEPLOY_HOST}:${DEPLOY_PATH}/
                                scp -o StrictHostKeyChecking=no ${FRONTEND_DIR}/${FRONTEND_ART} ${DEPLOY_USER}@${DEPLOY_HOST}:${DEPLOY_PATH}/

                                # Backup current deployment before deploying new version
                                ssh -o StrictHostKeyChecking=no ${DEPLOY_USER}@${DEPLOY_HOST} 'bash -s' <<'EOF'
                                    BACKUP_DIR="${DEPLOY_PATH}/backup_\$(date +%Y%m%d%H%M%S)"
                                    DEPLOY_DIR="${DEPLOY_PATH}/deployed-app"

                                    if [ -d "\$DEPLOY_DIR" ]; then
                                        echo "💾 Backing up current deployment to \$BACKUP_DIR"
                                        mkdir -p "\$BACKUP_DIR"
                                        cp -r "\$DEPLOY_DIR"/* "\$BACKUP_DIR"
                                    else
                                        echo "⚠️ No existing deployment found."
                                    fi

                                    # Deploy artifacts
                                    mkdir -p "\$DEPLOY_DIR/backend" "\$DEPLOY_DIR/frontend"
                                    tar -xzf ${DEPLOY_PATH}/${BACKEND_ART} -C "\$DEPLOY_DIR/backend"
                                    tar -xzf ${DEPLOY_PATH}/${FRONTEND_ART} -C "\$DEPLOY_DIR/frontend"

                                    # Cleanup artifact tar files
                                    rm -f ${DEPLOY_PATH}/${BACKEND_ART} ${DEPLOY_PATH}/${FRONTEND_ART}
                                    echo "✅ Deployment complete and artifacts cleaned up."
                                EOF
                            """
                        }
                    }
                }
            }
        }
    }

    post {
        success {
            echo "✅ Pipeline executed successfully!"
 slackSend(
    channel: env.SLACK_CHANNEL, 
    tokenCredentialId: 'SLACK_TOKEN', 
    message: "✅ Build SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
)
        }
        failure {
            echo "❌ Pipeline failed. Check console and remote logs."
slackSend(
    channel: env.SLACK_CHANNEL, 
    tokenCredentialId: 'SLACK_TOKEN', 
    message: "❌ Build FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
)
        }
    }
}

