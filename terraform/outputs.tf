output "vpc_id" {
  description = "ID of the VPC"
  value       = local.vpc_id
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = local.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = local.public_subnets
}

output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = local.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the load balancer"
  value       = local.alb_zone_id
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.id
}

output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = local.lambda_function_name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = local.s3_bucket_id
}

output "application_url" {
  description = "Application URL via CloudFront"
  value       = "http://${aws_cloudfront_distribution.main.domain_name}"
}

output "direct_alb_url" {
  description = "Direct ALB URL (for testing)"
  value       = "http://${local.alb_dns_name}"
} 