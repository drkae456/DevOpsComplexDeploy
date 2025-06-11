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

# Variables for checking existing resources
variable "use_existing_vpc" {
  description = "Whether to use an existing VPC instead of creating a new one."
  type        = bool
  default     = false
}

variable "use_existing_s3_bucket" {
  description = "Whether to use an existing S3 bucket instead of creating a new one."
  type        = bool
  default     = false
}

variable "existing_bucket_suffix" {
  description = "The suffix of the existing S3 bucket (if using existing bucket)."
  type        = string
  default     = ""
}

variable "use_existing_dynamodb" {
  description = "Whether to use an existing DynamoDB table instead of creating a new one."
  type        = bool
  default     = false
}

variable "use_existing_lambda" {
  description = "Whether to use an existing Lambda function instead of creating a new one."
  type        = bool
  default     = false
}

variable "use_existing_alb" {
  description = "Whether to use an existing ALB instead of creating a new one."
  type        = bool
  default     = false
}

