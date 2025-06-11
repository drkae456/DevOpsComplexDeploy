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
  # You will pass this in from GitHub Actions after the build step
}