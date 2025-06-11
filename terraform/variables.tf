variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "ap-southeast-4"
}

variable "app_name" {
  description = "The name of the application."
  type        = string
  default     = "serverless-fastapi-app"
}

variable "ecr_image_uri" {
  description = "The full URI of the Docker image in ECR."
  type        = string
  default = "014901325917.dkr.ecr.ap-southeast-4.amazonaws.com/serverless-fastapi-app"
  # You will pass this in from GitHub Actions after the build step
}

# Variables for CloudFormation stack deployment
variable "use_existing_vpc" {
  description = "Whether to use an existing VPC instead of creating a new one."
  type        = bool
  default     = false
}

