#!/bin/bash

# Import DynamoDB table
terraform import aws_dynamodb_table.main serverless-fastapi-app-table

# Import IAM role
terraform import aws_iam_role.fastapi_lambda serverless-fastapi-app-fastapi-lambda-role

# Import ECR repository
terraform import aws_ecr_repository.app serverless-fastapi-app

echo "Import completed. Now run: terraform apply -auto-approve" 