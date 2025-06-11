# CloudFormation Stack Management via Terraform
# This approach gives us CloudFormation's automatic rollback with Terraform's flexibility

# Data source to get existing VPC if needed
data "aws_vpc" "existing" {
  count = var.use_existing_vpc ? 1 : 0
  tags = {
    Name = "${var.app_name}-vpc"
  }
}

data "aws_subnets" "existing_private" {
  count = var.use_existing_vpc ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing[0].id]
  }
  tags = {
    Type = "Private"
  }
}

data "aws_subnets" "existing_public" {
  count = var.use_existing_vpc ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing[0].id]
  }
  tags = {
    Type = "Public"
  }
}

# Main CloudFormation Stack
resource "aws_cloudformation_stack" "serverless_app" {
  name         = "${var.app_name}-stack"
  template_body = file("${path.module}/cloudformation/serverless-app-stack.yaml")
  capabilities = ["CAPABILITY_NAMED_IAM"]
  
  parameters = {
    AppName            = var.app_name
    ECRImageURI        = var.ecr_image_uri
    UseExistingVPC     = var.use_existing_vpc ? "true" : "false"
    ExistingVPCId      = var.use_existing_vpc ? data.aws_vpc.existing[0].id : ""
    ExistingPrivateSubnets = var.use_existing_vpc ? join(",", data.aws_subnets.existing_private[0].ids) : ""
    ExistingPublicSubnets  = var.use_existing_vpc ? join(",", data.aws_subnets.existing_public[0].ids) : ""
  }

  # Rollback configuration
  on_failure = "ROLLBACK"
  
  # Timeout settings
  timeout_in_minutes = 30

  tags = {
    Name        = "${var.app_name}-stack"
    Environment = "production"
    ManagedBy   = "terraform"
  }

  # Lifecycle management
  lifecycle {
    # Prevent accidental deletion
    prevent_destroy = false
    
    # Ignore changes to template_body if using external updates
    ignore_changes = []
  }
}

# ECR Repository (managed separately for reliability)
resource "aws_ecr_repository" "app" {
  name                 = var.app_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = var.app_name
  }
}

# Outputs from CloudFormation stack
output "cloudformation_stack_outputs" {
  description = "All outputs from the CloudFormation stack"
  value       = aws_cloudformation_stack.serverless_app.outputs
}

output "load_balancer_url" {
  description = "URL of the load balancer"
  value       = lookup(aws_cloudformation_stack.serverless_app.outputs, "LoadBalancerURL", "")
}

output "cloudfront_url" {
  description = "CloudFront distribution URL"
  value       = lookup(aws_cloudformation_stack.serverless_app.outputs, "CloudFrontURL", "")
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = lookup(aws_cloudformation_stack.serverless_app.outputs, "LambdaFunctionArn", "")
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = lookup(aws_cloudformation_stack.serverless_app.outputs, "DynamoDBTableName", "")
}

output "deployment_status" {
  description = "Deployment status summary"
  value = {
    stack_status  = aws_cloudformation_stack.serverless_app.status
    stack_id      = aws_cloudformation_stack.serverless_app.id
    ecr_repository = aws_ecr_repository.app.repository_url
    vpc_created   = !var.use_existing_vpc
    timestamp     = timestamp()
  }
} 