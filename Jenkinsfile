pipeline {
    agent any

    environment {
        AWS_REGION         = 'il-central-1'
        ECR_REPO           = 'oleg/helm/nginx'
        IMAGE_NAME         = 'nginx'
        VAULT_ADDR         = 'http://vault:8200'
        VAULT_SECRET_PATH  = 'aws-creds/data/oleg'
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
                    echo "🔖 New image tag: ${env.IMAGE_TAG}"
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

        stage('Fetch AWS Credentials from Vault via HTTP') {
            steps {
                withCredentials([string(credentialsId: 'vault-token', variable: 'VAULT_TOKEN')]) {
                    script {
                        def resp = httpRequest(
                            httpMode: 'GET',
                            url: "${VAULT_ADDR}/v1/${VAULT_SECRET_PATH}",
                            customHeaders: [[name: 'X-Vault-Token', value: VAULT_TOKEN]],
                            validResponseCodes: '200'
                        )
                        echo "🔍 Vault raw response: ${resp.content}"
                        def json = readJSON text: resp.content
                        def data = json.data?.data

                        if (data?.access_key_id && data?.secret_access_key) {
                            // remove any stray commas or whitespace
                            env.AWS_ACCESS_KEY_ID     = data.access_key_id.trim().replaceAll(/,+$/, '')
                            env.AWS_SECRET_ACCESS_KEY = data.secret_access_key.trim().replaceAll(/,+$/, '')
                            echo "✅ AWS creds retrieved from Vault"
                        } else {
                            error("❌ AWS credentials not found in Vault response: ${resp.content}")
                        }
                    }
                }
            }
        }

        stage('Login to ECR') {
            steps {
                sh '''
                    aws configure set aws_access_key_id     $AWS_ACCESS_KEY_ID
                    aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
                    aws configure set default.region        $AWS_REGION

                    aws ecr get-login-password --region $AWS_REGION \
                      | docker login --username AWS --password-stdin \
                        $(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com
                '''
            }
        }

        stage('Push to ECR') {
            steps {
                script {
                    def accountId = sh(
                        script: "aws sts get-caller-identity --query Account --output text",
                        returnStdout: true
                    ).trim()
                    def ecrUri = "${accountId}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"

                    sh """
                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ecrUri}:${IMAGE_TAG}
                        docker push ${ecrUri}:${IMAGE_TAG}
                    """
                    env.ECR_IMAGE_URI = "${ecrUri}:${IMAGE_TAG}"
                    echo "📦 Pushed ${IMAGE_NAME}:${IMAGE_TAG} → ${env.ECR_IMAGE_URI}"
                }
            }
        }

        stage('Configure Kubeconfig') {
            steps {
                withEnv(["KUBECONFIG=/tmp/eks.conf"]) {
                    echo "✅ KUBECONFIG set to $KUBECONFIG"
                }
            }
        }

        stage('Update Helm Chart') {
            steps {
                script {
                    // extract registry+repo (strip off ":tag")
                    def registryRepo = env.ECR_IMAGE_URI.split(':')[0]

                    // update values.yaml under nginx-deployment folder
                    sh """
                      sed -i 's|^\\s*repository:.*|  repository: ${registryRepo}|' nginx-deployment/values.yaml
                      sed -i 's|^\\s*tag:.*|  tag:        ${env.IMAGE_TAG}|'    nginx-deployment/values.yaml
                    """
                    echo "🔄 nginx-deployment/values.yaml updated → ${registryRepo}:${env.IMAGE_TAG}"
                }
            }
        }

        stage('Deploy with Helm') {
            steps {
                withEnv(["KUBECONFIG=/tmp/eks.conf"]) {
                    sh """
                      helm upgrade --install nginx-deployment ./nginx-deployment \\
                        --namespace default
                    """
                    echo "🚀 Helm release 'nginx-deployment' deployed/upgraded"
                }
            }
        }
    }
}
