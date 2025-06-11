#!/bin/bash

echo "Starting resource import process..."

# Import DynamoDB table (note: uses count, so import to [0])
echo "Importing DynamoDB table..."
terraform import 'aws_dynamodb_table.main[0]' serverless-fastapi-app-table

# Import IAM role
echo "Importing IAM role..."
terraform import aws_iam_role.fastapi_lambda serverless-fastapi-app-fastapi-lambda-role

# Import ECR repository
echo "Importing ECR repository..."
terraform import aws_ecr_repository.app serverless-fastapi-app

# Import Load Balancer Target Group
echo "Importing ALB target group..."
terraform import aws_lb_target_group.lambda serverless-fastapi-app-lambda-tg

# Import WAF Web ACL
echo "Importing WAF Web ACL..."
terraform import aws_wafv2_web_acl.main serverless-fastapi-app-waf

# Import VPC - automatically find the VPC ID
echo "Finding and importing VPC..."
VPC_ID=$(aws ec2 describe-vpcs --filters 'Name=tag:Name,Values=serverless-fastapi-app-vpc' --query 'Vpcs[0].VpcId' --output text)

if [ "$VPC_ID" != "None" ] && [ "$VPC_ID" != "" ]; then
    echo "Found VPC ID: $VPC_ID"
    terraform import "module.vpc[0].aws_vpc.this[0]" $VPC_ID
    echo "VPC imported successfully!"
else
    echo "WARNING: Could not find VPC with name 'serverless-fastapi-app-vpc'"
    echo "You may need to manually import the VPC or check if one exists"
fi

echo ""
echo "Import process completed!"
echo "Now run: terraform apply -auto-approve" 