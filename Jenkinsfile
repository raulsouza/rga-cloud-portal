pipeline {
    agent any

    environment {
        GOOGLE_APPLICATION_CREDENTIALS = credentials('jenkins-sa')  // Replace with your Jenkins credential ID
        PROJECT_ID = "sacred-veld-441410-f8"  // Replace with your GCP Project ID
        REGION = "us-central1"
        TF_VAR_project_id = "${PROJECT_ID}" // Passing project ID as environment variable for Terraform
    }

    stages {
        stage('Setup Terraform') {
            steps {
                // Initialize Terraform
                sh 'terraform init'
            }
        }

        stage('Plan Terraform Changes') {
            steps {
                // Run terraform plan to preview changes
                sh 'terraform plan -out=tfplan'
            }
        }

        stage('Apply Terraform') {
            steps {
                // Apply the changes in main.tf
                sh 'terraform apply -auto-approve tfplan'
            }
        }
    }

    post {
        always {
            // Clean up any temporary files
            deleteDir()
        }
    }
}
