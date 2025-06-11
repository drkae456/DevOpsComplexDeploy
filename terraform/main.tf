# --- SECURITY & COMPLIANCE ---
resource "aws_kms_key" "main" {
  description             = "KMS CMK for encrypting app data"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags = {
    Name = "${var.app_name}-key"
  }
}

# --- DATA TIER ---
resource "aws_s3_bucket" "static_assets" {
  bucket = "${var.app_name}-static-assets-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "${var.app_name}-static-assets"
  }
}

resource "aws_s3_bucket_versioning" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main.arn
    }
  }
}

resource "aws_dynamodb_global_table" "main" {
  name = "${var.app_name}-table"
  replica {
    region_name = var.aws_region
  }
  # Note: The schema (attributes, keys) is defined on the underlying
  # aws_dynamodb_table resource, which is implicitly created.
  # For simplicity, this is omitted. A real table needs attribute definitions.
}

# --- APPLICATION TIER (in Private Subnet) ---

# IAM Role for the FastAPI Lambda
resource "aws_iam_role" "fastapi_lambda" {
  name = "${var.app_name}-fastapi-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
  # Attach policies for S3, DynamoDB, EventBridge, CloudWatch Logs
}

# ECR Repository
resource "aws_ecr_repository" "app" {
  name                 = var.app_name
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

# FastAPI Lambda Function
resource "aws_lambda_function" "fastapi" {
  function_name = "${var.app_name}-fastapi"
  role          = aws_iam_role.fastapi_lambda.arn
  package_type  = "Image"
  image_uri     = var.ecr_image_uri
  timeout       = 30
  memory_size   = 512

  # Place the Lambda in the private subnet
  vpc_config {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_global_table.main.name
    }
  }
}

# --- API GATEWAY & EDGE ---

# HTTP API Gateway
resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.app_name}-http-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.fastapi.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "$default" # Catch-all route
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

# Give API Gateway permission to invoke the Lambda
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fastapi.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# CloudFront, Route53, ACM, and WAF resources would go here,
# pointing to the API Gateway as an origin.