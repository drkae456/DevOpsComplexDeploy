#!/bin/bash

set -e  # Exit on any error unless explicitly handled

echo "Starting robust resource import process..."

# Function to check if a resource is already in state
check_resource_in_state() {
    local resource_address="$1"
    terraform state show "$resource_address" >/dev/null 2>&1
}

# Function to safely import a resource
safe_import() {
    local resource_address="$1"
    local resource_id="$2"
    local resource_name="$3"
    
    echo "Checking $resource_name..."
    
    if check_resource_in_state "$resource_address"; then
        echo "✓ $resource_name already in state, skipping import"
        return 0
    fi
    
    echo "Importing $resource_name..."
    if terraform import "$resource_address" "$resource_id" 2>/dev/null; then
        echo "✓ Successfully imported $resource_name"
    else
        echo "⚠ Failed to import $resource_name (resource may not exist yet)"
    fi
}

# Function to find VPC ID
find_vpc_id() {
    aws ec2 describe-vpcs \
        --filters 'Name=tag:Name,Values=serverless-fastapi-app-vpc' \
        --query 'Vpcs[0].VpcId' \
        --output text 2>/dev/null || echo "None"
}

# Import DynamoDB table
safe_import 'aws_dynamodb_table.main[0]' 'serverless-fastapi-app-table' 'DynamoDB table'

# Import IAM role
safe_import 'aws_iam_role.fastapi_lambda' 'serverless-fastapi-app-fastapi-lambda-role' 'IAM role'

# Import ECR repository
safe_import 'aws_ecr_repository.app' 'serverless-fastapi-app' 'ECR repository'

# Import Load Balancer Target Group
safe_import 'aws_lb_target_group.lambda' 'serverless-fastapi-app-lambda-tg' 'ALB target group'

# Import WAF Web ACL
safe_import 'aws_wafv2_web_acl.main' 'serverless-fastapi-app-waf' 'WAF Web ACL'

# Import VPC - find the VPC ID automatically
echo "Checking for existing VPC..."
VPC_ID=$(find_vpc_id)

if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
    safe_import "module.vpc[0].aws_vpc.this[0]" "$VPC_ID" "VPC"
else
    echo "⚠ No existing VPC found with name 'serverless-fastapi-app-vpc'"
fi

echo ""
echo "✓ Import process completed!"
echo "Note: Some resources may not exist yet and will be created during apply."
echo "Now run: terraform apply -auto-approve" 