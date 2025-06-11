# Generate random suffix for bucket names
resource "random_id" "bucket_suffix" {
  byte_length = 8
}

# Check for existing VPC
data "aws_vpc" "existing" {
  count = var.use_existing_vpc ? 1 : 0
  tags = {
    Name = "${var.app_name}-vpc"
  }
}

# Check for existing S3 bucket
data "aws_s3_bucket" "existing_bucket" {
  count  = var.use_existing_s3_bucket ? 1 : 0
  bucket = "${var.app_name}-static-assets-${var.existing_bucket_suffix}"
}

# Check for existing DynamoDB table
data "aws_dynamodb_table" "existing_table" {
  count = var.use_existing_dynamodb ? 1 : 0
  name  = "${var.app_name}-table"
}

# Check for existing Lambda function
data "aws_lambda_function" "existing_lambda" {
  count         = var.use_existing_lambda ? 1 : 0
  function_name = "${var.app_name}-fastapi"
}

# Check for existing ALB
data "aws_lb" "existing_alb" {
  count = var.use_existing_alb ? 1 : 0
  name  = "${var.app_name}-alb"
}

# --- NETWORKING ---
# VPC Module (only create if not using existing)
module "vpc" {
  count   = var.use_existing_vpc ? 0 : 1
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.app_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway   = true
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.app_name}-vpc"
  }
}

# Local values to use existing or new VPC
locals {
  vpc_id                   = var.use_existing_vpc ? data.aws_vpc.existing[0].id : module.vpc[0].vpc_id
  private_subnets          = var.use_existing_vpc ? data.aws_subnets.existing_private[0].ids : module.vpc[0].private_subnets
  public_subnets           = var.use_existing_vpc ? data.aws_subnets.existing_public[0].ids : module.vpc[0].public_subnets
  vpc_cidr_block           = var.use_existing_vpc ? data.aws_vpc.existing[0].cidr_block : module.vpc[0].vpc_cidr_block
  private_route_table_ids  = var.use_existing_vpc ? data.aws_route_tables.existing_private[0].ids : module.vpc[0].private_route_table_ids
}

# Get existing subnets if using existing VPC
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

data "aws_route_tables" "existing_private" {
  count = var.use_existing_vpc ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing[0].id]
  }
  tags = {
    Type = "Private"
  }
}

# VPC Endpoints for AWS Services (only if creating new VPC)
resource "aws_vpc_endpoint" "lambda" {
  count               = var.use_existing_vpc ? 0 : 1
  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.lambda"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = {
    Name = "${var.app_name}-lambda-endpoint"
  }
}

resource "aws_vpc_endpoint" "ecr_api" {
  count               = var.use_existing_vpc ? 0 : 1
  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = {
    Name = "${var.app_name}-ecr-api-endpoint"
  }
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  count               = var.use_existing_vpc ? 0 : 1
  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = {
    Name = "${var.app_name}-ecr-dkr-endpoint"
  }
}

resource "aws_vpc_endpoint" "s3" {
  count             = var.use_existing_vpc ? 0 : 1
  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = local.private_route_table_ids

  tags = {
    Name = "${var.app_name}-s3-endpoint"
  }
}

resource "aws_vpc_endpoint" "dynamodb" {
  count             = var.use_existing_vpc ? 0 : 1
  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = local.private_route_table_ids

  tags = {
    Name = "${var.app_name}-dynamodb-endpoint"
  }
}

# Security Groups
resource "aws_security_group" "alb" {
  count       = var.use_existing_alb ? 0 : 1
  name_prefix = "${var.app_name}-alb-"
  vpc_id      = local.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-alb-sg"
  }
}

resource "aws_security_group" "lambda" {
  name_prefix = "${var.app_name}-lambda-"
  vpc_id      = local.vpc_id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [var.use_existing_alb ? data.aws_security_groups.existing_alb_sg[0].ids[0] : aws_security_group.alb[0].id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-lambda-sg"
  }
}

resource "aws_security_group" "vpc_endpoints" {
  count       = var.use_existing_vpc ? 0 : 1
  name_prefix = "${var.app_name}-vpce-"
  vpc_id      = local.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-vpce-sg"
  }
}

# Get existing ALB security group if using existing ALB
data "aws_security_groups" "existing_alb_sg" {
  count = var.use_existing_alb ? 1 : 0
  filter {
    name   = "group-name"
    values = ["${var.app_name}-alb-*"]
  }
}

# --- LOAD BALANCER ---
resource "aws_lb" "main" {
  count              = var.use_existing_alb ? 0 : 1
  name               = "${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = local.public_subnets

  enable_deletion_protection = false

  tags = {
    Name = "${var.app_name}-alb"
  }
}

# Local values for ALB
locals {
  alb_arn      = var.use_existing_alb ? data.aws_lb.existing_alb[0].arn : aws_lb.main[0].arn
  alb_dns_name = var.use_existing_alb ? data.aws_lb.existing_alb[0].dns_name : aws_lb.main[0].dns_name
  alb_zone_id  = var.use_existing_alb ? data.aws_lb.existing_alb[0].zone_id : aws_lb.main[0].zone_id
}

resource "aws_lb_target_group" "lambda" {
  name        = "${var.app_name}-lambda-tg"
  target_type = "lambda"
  
  tags = {
    Name = "${var.app_name}-lambda-tg"
  }
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = local.alb_arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lambda.arn
  }
}

resource "aws_lb_target_group_attachment" "lambda" {
  target_group_arn = aws_lb_target_group.lambda.arn
  target_id        = local.lambda_function_arn
  depends_on       = [aws_lambda_permission.alb]
}

# --- WAF ---
resource "aws_wafv2_web_acl" "main" {
  name  = "${var.app_name}-waf"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                 = "CommonRuleSetMetric"
      sampled_requests_enabled    = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                 = "KnownBadInputsRuleSetMetric"
      sampled_requests_enabled    = true
    }
  }

  tags = {
    Name = "${var.app_name}-waf"
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                 = "${var.app_name}WAFMetric"
    sampled_requests_enabled    = true
  }
}

# --- CLOUDFRONT ---
resource "aws_cloudfront_distribution" "main" {
  origin {
    domain_name = local.alb_dns_name
    origin_id   = "ALB-${var.app_name}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

      default_cache_behavior {
      allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods         = ["GET", "HEAD"]
      target_origin_id       = "ALB-${var.app_name}"
      compress               = true
      viewer_protocol_policy = "allow-all"

    forwarded_values {
      query_string = true
      headers      = ["*"]

      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  web_acl_id = aws_wafv2_web_acl.main.arn

  tags = {
    Name = "${var.app_name}-cloudfront"
  }
}

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
  count  = var.use_existing_s3_bucket ? 0 : 1
  bucket = "${var.app_name}-static-assets-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "${var.app_name}-static-assets"
  }
}

# Local values for S3 bucket
locals {
  s3_bucket_id  = var.use_existing_s3_bucket ? data.aws_s3_bucket.existing_bucket[0].id : aws_s3_bucket.static_assets[0].id
  s3_bucket_arn = var.use_existing_s3_bucket ? data.aws_s3_bucket.existing_bucket[0].arn : aws_s3_bucket.static_assets[0].arn
}

resource "aws_s3_bucket_versioning" "static_assets" {
  count  = var.use_existing_s3_bucket ? 0 : 1
  bucket = local.s3_bucket_id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "static_assets" {
  count  = var.use_existing_s3_bucket ? 0 : 1
  bucket = local.s3_bucket_id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main.arn
    }
  }
}

resource "aws_dynamodb_table" "main" {
  count          = var.use_existing_dynamodb ? 0 : 1
  name           = "${var.app_name}-table"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.main.arn
  }

  tags = {
    Name = "${var.app_name}-table"
  }
}

# Local values for DynamoDB table
locals {
  dynamodb_table_name = var.use_existing_dynamodb ? data.aws_dynamodb_table.existing_table[0].name : aws_dynamodb_table.main[0].name
  dynamodb_table_arn  = var.use_existing_dynamodb ? data.aws_dynamodb_table.existing_table[0].arn : aws_dynamodb_table.main[0].arn
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
}

# IAM Policy for Lambda to access VPC, CloudWatch, DynamoDB, and S3
resource "aws_iam_role_policy" "fastapi_lambda_policy" {
  name = "${var.app_name}-fastapi-lambda-policy"
  role = aws_iam_role.fastapi_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ]
        Resource = local.dynamodb_table_arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${local.s3_bucket_arn}/*"
      }
    ]
  })
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
  count         = var.use_existing_lambda ? 0 : 1
  function_name = "${var.app_name}-fastapi"
  role          = aws_iam_role.fastapi_lambda.arn
  package_type  = "Image"
  image_uri     = var.ecr_image_uri
  timeout       = 30
  memory_size   = 512

  # Place the Lambda in the private subnet
  vpc_config {
    subnet_ids         = local.private_subnets
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DYNAMODB_TABLE = local.dynamodb_table_name
    }
  }
}

# Local values for Lambda function
locals {
  lambda_function_arn         = var.use_existing_lambda ? data.aws_lambda_function.existing_lambda[0].arn : aws_lambda_function.fastapi[0].arn
  lambda_function_name        = var.use_existing_lambda ? data.aws_lambda_function.existing_lambda[0].function_name : aws_lambda_function.fastapi[0].function_name
  lambda_function_invoke_arn  = var.use_existing_lambda ? data.aws_lambda_function.existing_lambda[0].invoke_arn : aws_lambda_function.fastapi[0].invoke_arn
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
  integration_uri  = local.lambda_function_invoke_arn
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
  function_name = local.lambda_function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# Give ALB permission to invoke the Lambda
resource "aws_lambda_permission" "alb" {
  statement_id  = "AllowALBInvoke"
  action        = "lambda:InvokeFunction"
  function_name = local.lambda_function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.lambda.arn
}

# CloudFront, Route53, ACM, and WAF resources would go here,
# pointing to the API Gateway as an origin.