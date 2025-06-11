# terraform.tfvars
# Configuration for CloudFormation Stack Deployment

# Basic configuration
aws_region = "ap-southeast-4"
app_name   = "serverless-fastapi-app"

# VPC configuration - set to true to use existing VPC if available
use_existing_vpc = true

# ECR image URI will be passed from GitHub Actions
# ecr_image_uri = "014901325917.dkr.ecr.ap-southeast-4.amazonaws.com/serverless-fastapi-app:latest" 