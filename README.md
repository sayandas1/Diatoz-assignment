# Full-Stack Application Deployment on AWS ECS with CI/CD

This project demonstrates how to deploy a full-stack application on an AWS ECS cluster using Infrastructure as Code (IaC) with Terraform, along with automated Continuous Integration (CI) and Continuous Deployment (CD) using AWS services like CodePipeline and CodeBuild.

## Features

- Sets up a VPC with public and private subnets on AWS.
- Restricts access using security groups for frontend and backend services.
- Automates CI/CD pipeline using AWS CodePipeline.
- Builds Docker images and pushes them to Amazon ECR.
- Deploys Docker images to ECS Fargate cluster.
- Creates CloudWatch alarms for monitoring ECS instances.

## Prerequisites

Before you begin, ensure you have the following:

- An AWS account with appropriate permissions.
- Terraform installed on your local machine.
- GitHub repository for your application with appropriate access tokens.

## Getting Started

1. Clone this repository:

git clone https://github.com/sayandas1/Diatoz-assignment

cd Diatoz-assignment

2. Update the `terraform.tfvars` file with your AWS credentials and GitHub repository details:

```hcl
github_repo_owner = "your-github-owner"
github_repo_name = "your-repo-name"
github_branch = "main"
github_token = "your-github-token"

aws_access_key = "your-aws-access-key"
aws_secret_key = "your-aws-secret-key"

Initialize Terraform and apply the configuration:

terraform init
terraform apply

Once the infrastructure is deployed, push your code changes to your GitHub repository to trigger the CI/CD pipeline.

Files and Configuration
main.tf: Contains the Terraform configuration for setting up AWS resources.
variables.tf: Defines input variables for the Terraform configuration.
buildspec.yml: Specifies the build phases and commands for CodeBuild.
imagedefinitions.json: Defines the Docker image to deploy to ECS.
.github/workflows/main.yml: GitHub Actions workflow for CI/CD pipeline.