#!/bin/bash

set -e

echo "🧹 AWS Resource Cleanup Script for DevOps Complex Deploy"
echo "========================================================"
echo ""
echo "⚠️  WARNING: This script will DELETE AWS resources!"
echo "Only use this if you're sure about removing conflicting resources."
echo ""

# Function to confirm actions
confirm_action() {
    local action="$1"
    echo ""
    read -p "❓ Do you want to $action? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "❌ Skipping $action"
        return 1
    fi
    return 0
}

# Function to cleanup target groups
cleanup_target_groups() {
    echo ""
    echo "🎯 Checking for existing target groups..."
    
    TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups \
        --names "serverless-fastapi-app-lambda-tg" \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text 2>/dev/null || echo "None")
    
    if [ "$TARGET_GROUP_ARN" != "None" ] && [ -n "$TARGET_GROUP_ARN" ]; then
        echo "Found target group: $TARGET_GROUP_ARN"
        if confirm_action "delete this target group"; then
            aws elbv2 delete-target-group --target-group-arn "$TARGET_GROUP_ARN"
            echo "✅ Target group deleted"
        fi
    else
        echo "✅ No conflicting target groups found"
    fi
}

# Function to cleanup WAF
cleanup_waf() {
    echo ""
    echo "🛡️  Checking for existing WAF Web ACL..."
    
    WAF_INFO=$(aws wafv2 list-web-acls --scope REGIONAL \
        --query 'WebACLs[?Name==`serverless-fastapi-app-waf`].[Id,LockToken]' \
        --output text 2>/dev/null || echo "None")
    
    if [ "$WAF_INFO" != "None" ] && [ -n "$WAF_INFO" ]; then
        WAF_ID=$(echo "$WAF_INFO" | awk '{print $1}')
        LOCK_TOKEN=$(echo "$WAF_INFO" | awk '{print $2}')
        
        echo "Found WAF Web ACL: $WAF_ID"
        if confirm_action "delete this WAF Web ACL"; then
            # First, get the current lock token
            CURRENT_LOCK_TOKEN=$(aws wafv2 get-web-acl \
                --scope REGIONAL \
                --id "$WAF_ID" \
                --query 'LockToken' \
                --output text)
            
            aws wafv2 delete-web-acl \
                --scope REGIONAL \
                --id "$WAF_ID" \
                --lock-token "$CURRENT_LOCK_TOKEN"
            echo "✅ WAF Web ACL deleted"
        fi
    else
        echo "✅ No conflicting WAF Web ACLs found"
    fi
}

# Function to cleanup VPCs and related resources
cleanup_vpc_resources() {
    echo ""
    echo "🌐 Checking for conflicting VPC resources..."
    
    # Find VPCs with our CIDR block
    CONFLICTING_VPCS=$(aws ec2 describe-vpcs \
        --filters 'Name=cidr-block,Values=10.0.0.0/16' \
        --query 'Vpcs[].VpcId' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$CONFLICTING_VPCS" ] && [ "$CONFLICTING_VPCS" != "None" ]; then
        echo "Found VPCs with conflicting CIDR blocks:"
        for vpc_id in $CONFLICTING_VPCS; do
            VPC_NAME=$(aws ec2 describe-vpcs --vpc-ids "$vpc_id" \
                --query 'Vpcs[0].Tags[?Key==`Name`].Value' \
                --output text 2>/dev/null || echo "unknown")
            echo "  - VPC: $vpc_id (Name: $VPC_NAME)"
        done
        
        echo ""
        echo "⚠️  VPC cleanup is complex and requires careful consideration!"
        echo "Deleting a VPC will also delete all associated resources:"
        echo "  - Subnets"
        echo "  - Route tables"
        echo "  - Security groups"
        echo "  - Internet gateways"
        echo "  - NAT gateways"
        echo ""
        
        if confirm_action "proceed with VPC cleanup (DESTRUCTIVE!)"; then
            for vpc_id in $CONFLICTING_VPCS; do
                echo ""
                echo "🗑️  Cleaning up VPC: $vpc_id"
                
                # This is a complex operation - recommend manual cleanup
                echo "❌ Automated VPC cleanup is too risky!"
                echo "Please manually clean up this VPC using the AWS Console or CLI"
                echo ""
                echo "Manual cleanup steps:"
                echo "1. Delete all EC2 instances in the VPC"
                echo "2. Delete all NAT gateways"
                echo "3. Delete all VPC endpoints"
                echo "4. Delete all subnets"
                echo "5. Detach and delete internet gateways"
                echo "6. Delete the VPC"
                echo ""
                echo "AWS CLI commands:"
                echo "aws ec2 describe-vpcs --vpc-ids $vpc_id"
                echo "aws ec2 delete-vpc --vpc-id $vpc_id"
            done
        fi
    else
        echo "✅ No conflicting VPCs found"
    fi
}

# Function to check limits
check_limits() {
    echo ""
    echo "📊 Checking AWS resource limits..."
    
    # Check Internet Gateway count
    IGW_COUNT=$(aws ec2 describe-internet-gateways --query 'length(InternetGateways)' --output text 2>/dev/null || echo "0")
    echo "Internet Gateways: $IGW_COUNT/5 (typical limit)"
    
    # Check VPC count
    VPC_COUNT=$(aws ec2 describe-vpcs --query 'length(Vpcs)' --output text 2>/dev/null || echo "0")
    echo "VPCs: $VPC_COUNT/5 (default limit)"
    
    # Check if we're at limits
    if [ "$IGW_COUNT" -ge 5 ]; then
        echo "⚠️  You're at the Internet Gateway limit!"
    fi
    
    if [ "$VPC_COUNT" -ge 5 ]; then
        echo "⚠️  You're at the VPC limit!"
    fi
}

# Main menu
main_menu() {
    echo ""
    echo "🔧 What would you like to clean up?"
    echo ""
    echo "1) Clean up Target Groups"
    echo "2) Clean up WAF Web ACLs"
    echo "3) Check VPC conflicts (manual cleanup required)"
    echo "4) Check resource limits"
    echo "5) Run all checks (recommended)"
    echo "6) Exit"
    echo ""
    read -p "Choose an option (1-6): " -r choice
    
    case $choice in
        1) cleanup_target_groups ;;
        2) cleanup_waf ;;
        3) cleanup_vpc_resources ;;
        4) check_limits ;;
        5) 
            cleanup_target_groups
            cleanup_waf
            cleanup_vpc_resources
            check_limits
            ;;
        6) 
            echo "👋 Goodbye!"
            exit 0
            ;;
        *) 
            echo "❌ Invalid option"
            main_menu
            ;;
    esac
}

# Check if AWS CLI is configured
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "❌ AWS CLI is not configured or you don't have permissions"
    echo "Please run: aws configure"
    exit 1
fi

echo "✅ AWS CLI is configured"
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)
echo "Account: $AWS_ACCOUNT"
echo "Region: $AWS_REGION"

# Run main menu
main_menu

echo ""
echo "🎉 Cleanup process completed!"
echo ""
echo "Next steps:"
echo "1. Run the enhanced import script: ./import.sh"
echo "2. Create terraform.tfvars if needed"
echo "3. Run: terraform plan"
echo "4. Run: terraform apply" 