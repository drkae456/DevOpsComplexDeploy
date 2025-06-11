# CloudFormation Stack Deployment with Terraform & GitHub Actions

This project now uses a **hybrid approach** combining **CloudFormation YAML templates** with **Terraform management** and **GitHub Actions** for robust, retry-enabled deployments.

## 🌟 Why This Approach?

### Benefits:

- ✅ **Automatic Rollback**: CloudFormation handles rollbacks on failure
- ✅ **No Resource Conflicts**: CloudFormation manages dependencies automatically
- ✅ **Retry Logic**: Automatic cleanup and retry on failures
- ✅ **Best of Both Worlds**: CloudFormation reliability + Terraform flexibility
- ✅ **Manual Override**: Force recreate entire stack if needed

### Problems This Solves:

- ❌ Target Group already exists errors
- ❌ WAF duplicate resource errors
- ❌ VPC CIDR conflicts
- ❌ Internet Gateway limits
- ❌ Manual resource cleanup needs

## 📁 File Structure

```
├── .github/workflows/
│   ├── deploy.yml                    # Original Terraform workflow
│   └── deploy-cloudformation.yml     # New CloudFormation workflow
├── terraform/
│   ├── cloudformation/
│   │   └── serverless-app-stack.yaml # CloudFormation template
│   ├── cloudformation-stack.tf       # Terraform CloudFormation management
│   ├── main.tf.old                   # Original Terraform config (backup)
│   ├── variables.tf                  # Simplified variables
│   ├── terraform.tfvars              # Configuration
│   ├── import.sh                     # Import script (legacy)
│   └── cleanup.sh                    # Cleanup script (legacy)
```

## 🚀 Deployment Options

### Option 1: Automatic Deployment (Recommended)

Push to `main` branch - uses existing VPC if available:

```bash
git push origin main
```

### Option 2: Force Recreate Everything

Use GitHub Actions manual trigger:

1. Go to Actions tab in GitHub
2. Select "Deploy with CloudFormation Stack Management"
3. Click "Run workflow"
4. Set "Force recreate" to `true`
5. Set retry count (default: 3)

### Option 3: Local Testing (if AWS CLI configured)

```bash
cd terraform
terraform init
terraform plan -var="ecr_image_uri=YOUR_IMAGE_URI"
terraform apply -var="ecr_image_uri=YOUR_IMAGE_URI"
```

## 🏗️ What Gets Created

The CloudFormation stack creates:

### Core Infrastructure:

- **VPC** with public/private subnets (if use_existing_vpc=false)
- **Internet Gateway** and **NAT Gateway**
- **Route Tables** and associations

### Application Resources:

- **Lambda Function** (containerized FastAPI)
- **Application Load Balancer** (ALB)
- **Target Group** for Lambda
- **CloudFront Distribution**
- **WAF Web ACL** with AWS managed rules

### Data & Security:

- **DynamoDB Table** (pay-per-request)
- **S3 Bucket** for static assets
- **KMS Key** for encryption
- **IAM Role** for Lambda
- **Security Groups** for ALB and Lambda

## 🔧 Configuration

### terraform.tfvars

```hcl
aws_region = "ap-southeast-4"
app_name   = "serverless-fastapi-app"
use_existing_vpc = true  # Set to false for new VPC
```

### GitHub Secrets Required:

- `AWS_ROLE_TO_ASSUME`: ARN of IAM role for GitHub OIDC

## 🔄 Retry Logic Flow

1. **Attempt Deployment**: Run terraform plan → apply
2. **On Failure**:
   - Check CloudFormation stack status
   - If stack is in failed state → delete it
   - Clean up terraform state
   - Wait 30 seconds
   - Retry (up to 3 times by default)
3. **On Success**: Validate endpoints and outputs
4. **Final Cleanup**: Remove failed stacks if all retries exhausted

## 🛠️ Manual Troubleshooting

### Check Stack Status:

```bash
aws cloudformation describe-stacks --stack-name serverless-fastapi-app-stack
```

### View Stack Events:

```bash
aws cloudformation describe-stack-events --stack-name serverless-fastapi-app-stack
```

### Force Delete Stuck Stack:

```bash
aws cloudformation delete-stack --stack-name serverless-fastapi-app-stack
aws cloudformation wait stack-delete-complete --stack-name serverless-fastapi-app-stack
```

### Check Resources:

```bash
# Target Groups
aws elbv2 describe-target-groups --names "serverless-fastapi-app-lambda-tg"

# WAF Web ACLs
aws wafv2 list-web-acls --scope REGIONAL

# VPCs with CIDR conflicts
aws ec2 describe-vpcs --filters 'Name=cidr-block,Values=10.0.0.0/16'
```

## 📊 Monitoring

### CloudFormation Console:

https://console.aws.amazon.com/cloudformation/home?region=ap-southeast-4#/stacks

### Key Outputs:

- **LoadBalancerURL**: Direct ALB access
- **CloudFrontURL**: CDN-cached access
- **LambdaFunctionArn**: Lambda function ARN
- **DynamoDBTableName**: Database table name

## 🚨 Emergency Procedures

### Complete Stack Reset:

1. Delete CloudFormation stack:
   ```bash
   aws cloudformation delete-stack --stack-name serverless-fastapi-app-stack
   ```
2. Clean terraform state:
   ```bash
   cd terraform
   rm -rf .terraform.lock.hcl terraform.tfstate*
   terraform init
   ```
3. Redeploy via GitHub Actions with "Force recreate" = true

### Rollback to Previous Version:

1. Find previous working ECR image tag
2. Update terraform.tfvars with old image URI
3. Run deployment

## 🔍 Debugging

### Common Issues:

1. **"Stack does not exist"**:

   - Check stack name and region
   - Run with force_recreate=true

2. **"Insufficient IAM permissions"**:

   - Verify AWS_ROLE_TO_ASSUME has CloudFormation permissions
   - Check OIDC trust relationship

3. **"Template validation failed"**:

   - Validate CloudFormation template:
     ```bash
     aws cloudformation validate-template --template-body file://cloudformation/serverless-app-stack.yaml
     ```

4. **Resource still exists after cleanup**:
   - Some resources may have deletion protection
   - Check AWS Console and delete manually

## 📈 Benefits of This Approach

### vs Pure Terraform:

- ✅ Better rollback handling
- ✅ Cleaner resource dependencies
- ✅ Built-in retry logic
- ✅ Stack-level operations

### vs Pure CloudFormation:

- ✅ Version control friendly
- ✅ Terraform ecosystem integration
- ✅ Better variable management
- ✅ Cross-stack references

### vs Manual Deployment:

- ✅ Fully automated
- ✅ Consistent environments
- ✅ Audit trail
- ✅ Easy rollbacks

This approach should eliminate all the resource conflicts you were experiencing while providing robust deployment capabilities! 🎉
