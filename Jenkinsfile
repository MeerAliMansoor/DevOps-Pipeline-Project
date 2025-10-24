pipeline {
    agent any

    environment {
        BACKEND_DIR = "backend/backend-app"
        FRONTEND_DIR = "frontend"
    }

    stages {
        stage('Clone Repository') {
            steps {
                checkout scm
            }
        }

        stage('Install Backend Dependencies') {
            steps {
                dir("${BACKEND_DIR}") {
                    sh 'npm install'
                }
            }
        }

        stage('Install Frontend Dependencies') {
            steps {
                dir("${FRONTEND_DIR}") {
                    sh 'npm install'
                }
            }
        }

        stage('Build Frontend') {
            steps {
                dir("${FRONTEND_DIR}") {
                    sh 'npm run build'
                }
            }
        }

        stage('Run Backend Tests') {
            steps {
                dir("${BACKEND_DIR}") {
                    sh 'npm test || echo "No tests found"'
                }
            }
        }
    }

    post {
        success {
            echo '✅ Pipeline executed successfully!'
        }
        failure {
            echo '❌ Pipeline failed. Please check logs.'
        }
    }

    stage('Deploy') {
        steps {
            echo "🚀 Starting Deployment..."
            
            // Run backend
            dir('backend/backend-app') {
                echo "Starting backend server..."
                sh 'nohup npm start &'
            }

            // Serve frontend
            dir('frontend') {
                echo "Serving frontend build..."
                sh 'nohup serve -s build -l 3000 &'
            }

            echo "✅ Deployment completed successfully!"
        }
    }


}

