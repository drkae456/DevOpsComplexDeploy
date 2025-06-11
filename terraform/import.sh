#!/bin/bash

set -e  # Exit on any error unless explicitly handled

echo "Starting comprehensive resource import/cleanup process..."

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

# Function to find conflicting VPCs/subnets and clean them up
cleanup_conflicting_resources() {
    echo ""
    echo "=== CHECKING FOR CONFLICTING RESOURCES ==="
    
    # Find VPCs with conflicting CIDR blocks
    echo "Checking for VPCs with conflicting CIDR blocks..."
    CONFLICTING_VPCS=$(aws ec2 describe-vpcs \
        --filters 'Name=cidr-block,Values=10.0.0.0/16' \
        --query 'Vpcs[?CidrBlock==`10.0.0.0/16`].VpcId' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$CONFLICTING_VPCS" ] && [ "$CONFLICTING_VPCS" != "None" ]; then
        echo "Found VPCs with conflicting CIDR blocks: $CONFLICTING_VPCS"
        echo ""
        echo "⚠️  WARNING: There are existing VPCs with conflicting CIDR blocks."
        echo "This will cause subnet creation to fail."
        echo ""
        echo "Options to resolve:"
        echo "1. Use existing VPC (recommended): Set use_existing_vpc = true in terraform.tfvars"
        echo "2. Delete conflicting VPCs manually"
        echo "3. Change CIDR blocks in main.tf"
        echo ""
        
        # Check if any of these VPCs can be imported
        for vpc_id in $CONFLICTING_VPCS; do
            VPC_NAME=$(aws ec2 describe-vpcs --vpc-ids "$vpc_id" \
                --query 'Vpcs[0].Tags[?Key==`Name`].Value' \
                --output text 2>/dev/null || echo "unknown")
            echo "VPC: $vpc_id (Name: $VPC_NAME)"
            
            if [ "$VPC_NAME" = "serverless-fastapi-app-vpc" ]; then
                echo "  -> This VPC matches our app name, attempting to import..."
                safe_import "module.vpc[0].aws_vpc.this[0]" "$vpc_id" "VPC"
                
                # Try to import subnets
                echo "  -> Looking for subnets to import..."
                SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" \
                    --query 'Subnets[].SubnetId' --output text 2>/dev/null || echo "")
                
                for subnet_id in $SUBNETS; do
                    SUBNET_CIDR=$(aws ec2 describe-subnets --subnet-ids "$subnet_id" \
                        --query 'Subnets[0].CidrBlock' --output text 2>/dev/null)
                    echo "    Found subnet: $subnet_id ($SUBNET_CIDR)"
                done
            fi
        done
    fi
    
    # Check for existing target groups
    echo ""
    echo "Checking for existing target groups..."
    TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups \
        --names "serverless-fastapi-app-lambda-tg" \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text 2>/dev/null || echo "None")
    
    if [ "$TARGET_GROUP_ARN" != "None" ] && [ -n "$TARGET_GROUP_ARN" ]; then
        echo "Found existing target group: $TARGET_GROUP_ARN"
        safe_import 'aws_lb_target_group.lambda' "$TARGET_GROUP_ARN" 'ALB target group'
    fi
    
    # Check for existing WAF
    echo ""
    echo "Checking for existing WAF Web ACL..."
    WAF_ID=$(aws wafv2 list-web-acls --scope REGIONAL \
        --query 'WebACLs[?Name==`serverless-fastapi-app-waf`].Id' \
        --output text 2>/dev/null || echo "None")
    
    if [ "$WAF_ID" != "None" ] && [ -n "$WAF_ID" ]; then
        echo "Found existing WAF Web ACL: $WAF_ID"
        WAF_ARN="arn:aws:wafv2:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):regional/webacl/serverless-fastapi-app-waf/$WAF_ID"
        safe_import 'aws_wafv2_web_acl.main' "$WAF_ARN" 'WAF Web ACL'
    fi
    
    # Check Internet Gateway limits
    echo ""
    echo "Checking Internet Gateway limits..."
    IGW_COUNT=$(aws ec2 describe-internet-gateways --query 'length(InternetGateways)' --output text 2>/dev/null || echo "0")
    echo "Current Internet Gateways: $IGW_COUNT"
    
    if [ "$IGW_COUNT" -ge 5 ]; then
        echo "⚠️  WARNING: You're approaching or at the Internet Gateway limit (usually 5 per region)"
        echo "Consider using an existing VPC or cleaning up unused IGWs"
    fi
    
    echo ""
    echo "=== RESOURCE CONFLICT CHECK COMPLETE ==="
}

# Function to suggest terraform.tfvars configuration
suggest_tfvars() {
    echo ""
    echo "=== SUGGESTED TERRAFORM.TFVARS CONFIGURATION ==="
    echo ""
    echo "# Create this file as terraform.tfvars to use existing resources:"
    echo "use_existing_vpc = true"
    echo "use_existing_s3_bucket = false"  
    echo "use_existing_dynamodb = false"
    echo "use_existing_lambda = false"
    echo "use_existing_alb = false"
    echo ""
    echo "# If you want to avoid conflicts completely, set all to true:"
    echo "# use_existing_vpc = true"
    echo "# use_existing_s3_bucket = true" 
    echo "# use_existing_dynamodb = true"
    echo "# use_existing_lambda = true"
    echo "# use_existing_alb = true"
    echo ""
}

# Main import process
echo "=== STARTING STANDARD IMPORTS ==="

# Import DynamoDB table
safe_import 'aws_dynamodb_table.main[0]' 'serverless-fastapi-app-table' 'DynamoDB table'

# Import IAM role
safe_import 'aws_iam_role.fastapi_lambda' 'serverless-fastapi-app-fastapi-lambda-role' 'IAM role'

# Import ECR repository
safe_import 'aws_ecr_repository.app' 'serverless-fastapi-app' 'ECR repository'

# Run conflict detection and cleanup
cleanup_conflicting_resources

# Import VPC - find the VPC ID automatically
echo ""
echo "=== VPC IMPORT PROCESS ==="
VPC_ID=$(find_vpc_id)

if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
    safe_import "module.vpc[0].aws_vpc.this[0]" "$VPC_ID" "VPC"
    echo "✓ Found and imported VPC: $VPC_ID"
else
    echo "⚠ No existing VPC found with name 'serverless-fastapi-app-vpc'"
fi

suggest_tfvars

echo ""
echo "✓ Import process completed!"
echo ""
echo "NEXT STEPS:"
echo "1. Review the suggestions above"
echo "2. Create terraform.tfvars file if you want to use existing resources"
echo "3. If conflicts remain, either:"
echo "   a) Clean up conflicting resources manually, or"
echo "   b) Set use_existing_vpc = true in terraform.tfvars"
echo "4. Run: terraform plan (to review changes)"
echo "5. Run: terraform apply -auto-approve"
echo "" 