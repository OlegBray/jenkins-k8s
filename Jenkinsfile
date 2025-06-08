pipeline {
    agent any

    environment {
        IMAGE_NAME = "nginx"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Set Version') {
            steps {
                script {
                    def version = readFile('version.txt').trim()
                    env.VERSION = version
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    docker.build("${IMAGE_NAME}:${VERSION}")
                }
            }
        }

        stage('Get AWS Credentials from Vault') {
            steps {
                script {
                    withVault([
                        vaultSecrets: [[
                            path: 'aws-creds/data/oleg', // <-- Adjust path if needed
                            engineVersion: 2,
                            secretValues: [
                                [vaultKey: 'AWS_ACCESS_KEY_ID', envVar: 'AWS_ACCESS_KEY_ID'],
                                [vaultKey: 'AWS_SECRET_ACCESS_KEY', envVar: 'AWS_SECRET_ACCESS_KEY']
                            ]
                        ]]
                    ]) {
                        echo "AWS credentials loaded from Vault."
                        // You can now use AWS CLI or Docker login to ECR with these env vars
                    }
                }
            }
        }

        stage('Login to ECR') {
            steps {
                sh '''
                    aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
                    aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
                    aws ecr get-login-password --region il-central-1 | docker login --username AWS --password-stdin 314525640319.dkr.ecr.il-central-1.amazonaws.com
                '''
            }
        }

        stage('Push to ECR') {
            steps {
                sh '''
                    docker tag ${IMAGE_NAME}:${VERSION} 314525640319.dkr.ecr.il-central-1.amazonaws.com/imtech-oleg:${VERSION}
                    docker push 314525640319.dkr.ecr.il-central-1.amazonaws.com/imtech-oleg:${VERSION}
                '''
            }
        }
    }
}
