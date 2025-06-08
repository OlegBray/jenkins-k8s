pipeline {
    agent any

    environment {
        AWS_REGION = 'il-central-1'
        ECR_REPO = 'oleg/helm/nginx'
        IMAGE_NAME = 'nginx'
        VAULT_SECRET_PATH = 'aws-creds/oleg' // Adjusted for Vault plugin format
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
                    def versionFile = 'VERSION'
                    def version = '0.1'
                    if (fileExists(versionFile)) {
                        version = readFile(versionFile).trim()
                        def (major, minor) = version.tokenize('.')
                        minor = minor.toInteger() + 1
                        if (minor > 9) {
                            major = major.toInteger() + 1
                            minor = 0
                        }
                        version = "${major}.${minor}"
                    }
                    writeFile file: versionFile, text: version
                    env.IMAGE_TAG = version
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    def dockerImage = docker.build("${IMAGE_NAME}:${env.IMAGE_TAG}")
                }
            }
        }

        stage('Get AWS Credentials from Vault') {
            steps {
                script {
                    withVault([
                        vaultSecrets: [[
                            path: "${VAULT_SECRET_PATH}",
                            secretValues: [
                                [envVar: 'AWS_ACCESS_KEY_ID', vaultKey: 'AWS_ACCESS_KEY_ID'],
                                [envVar: 'AWS_SECRET_ACCESS_KEY', vaultKey: 'AWS_SECRET_ACCESS_KEY']
                            ]
                        ]]
                    ]) {
                        echo "AWS credentials retrieved from Vault"
                    }
                }
            }
        }

        stage('Login to ECR') {
            steps {
                script {
                    sh '''
                        aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
                        aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
                        aws configure set default.region $AWS_REGION

                        aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com
                    '''
                }
            }
        }

        stage('Push to ECR') {
            steps {
                script {
                    def accountId = sh(script: "aws sts get-caller-identity --query Account --output text", returnStdout: true).trim()
                    def ecrRepoUri = "${accountId}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
                    sh "docker tag ${IMAGE_NAME}:${env.IMAGE_TAG} ${ecrRepoUri}:${env.IMAGE_TAG}"
                    sh "docker push ${ecrRepoUri}:${env.IMAGE_TAG}"
                    env.ECR_IMAGE_URI = "${ecrRepoUri}:${env.IMAGE_TAG}"
                }
            }
        }
    }
}
