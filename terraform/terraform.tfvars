# terraform.tfvars
# Configuration to SKIP already created resources

# Basic configuration
aws_region = "ap-southeast-4"
app_name   = "serverless-fastapi-app"

# Resource configuration - set to TRUE to use existing resources (avoid conflicts)

# VPC: Set to true to avoid subnet CIDR conflicts and IGW limit
use_existing_vpc = true

# DynamoDB: Set to true since it already exists
use_existing_dynamodb = true

# Other resources: Keep creating new ones if they don't conflict
use_existing_s3_bucket = false
use_existing_lambda = false
use_existing_alb = false

# ECR image URI will be passed from GitHub Actions
# ecr_image_uri = "014901325917.dkr.ecr.ap-southeast-4.amazonaws.com/serverless-fastapi-app:latest" 