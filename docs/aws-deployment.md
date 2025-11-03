# AWS Deployment Guide

This guide walks you through deploying Open WebUI to AWS using CloudFormation with full production-ready infrastructure.

## Architecture Overview

The deployment creates:
- **VPC** with public and private subnets across 2 AZs
- **Application Load Balancer** with HTTPS
- **ECS Fargate** for serverless container orchestration
- **EFS** for persistent storage
- **Cognito** for authentication
- **CloudWatch** for monitoring and logging
- **Secrets Manager** for secure credential storage

## Prerequisites

### Required

1. **AWS Account** with appropriate permissions
2. **AWS CLI** installed and configured ([Install Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
3. **ACM Certificate** for your domain in the target region
4. **S3 Bucket** for CloudFormation templates
5. **Domain name** (optional but recommended)

### Required AWS Permissions

Your IAM user/role needs permissions to create:
- VPC, Subnets, Internet Gateway, NAT Gateway
- Security Groups
- Application Load Balancer, Target Groups
- ECS Cluster, Services, Task Definitions
- EFS File Systems
- Cognito User Pools
- Secrets Manager Secrets
- CloudWatch Logs, Alarms, Dashboards
- IAM Roles and Policies
- KMS Keys

## Step 1: Prepare ACM Certificate

You need an SSL/TLS certificate for HTTPS.

### Option A: Request New Certificate

1. **Navigate to ACM Console:**
   ```bash
   https://console.aws.amazon.com/acm/
   ```

2. **Request certificate:**
   - Click "Request certificate"
   - Choose "Request a public certificate"
   - Enter your domain name (e.g., `openwebui.example.com`)
   - Choose DNS validation
   - Click "Request"

3. **Validate domain:**
   - Follow DNS validation instructions
   - Add CNAME record to your DNS
   - Wait for validation (usually 5-30 minutes)

4. **Copy Certificate ARN:**
   - Format: `arn:aws:acm:region:account-id:certificate/certificate-id`

### Option B: Use Existing Certificate

If you already have a certificate, copy its ARN from ACM Console.

## Step 2: Create S3 Bucket for Templates

CloudFormation nested stacks require templates to be in S3.

```bash
# Set your bucket name (must be globally unique)
export BUCKET_NAME="my-openwebui-cfn-templates"
export AWS_REGION="us-east-1"

# Create bucket
aws s3 mb s3://${BUCKET_NAME} --region ${AWS_REGION}

# Enable versioning (recommended)
aws s3api put-bucket-versioning \
  --bucket ${BUCKET_NAME} \
  --versioning-configuration Status=Enabled
```

## Step 3: Upload CloudFormation Templates

Upload all templates to S3:

```bash
# Navigate to project directory
cd open-webui-aws-deployment

# Upload templates
aws s3 sync cloudformation/ s3://${BUCKET_NAME}/ \
  --exclude "main-stack.yaml" \
  --region ${AWS_REGION}

# Verify upload
aws s3 ls s3://${BUCKET_NAME}/
```

## Step 4: Prepare Parameters

Create a parameters file for your environment:

```bash
cp examples/parameters-prod.json my-parameters.json
```

Edit `my-parameters.json`:

```json
[
  {
    "ParameterKey": "EnvironmentName",
    "ParameterValue": "open-webui-prod"
  },
  {
    "ParameterKey": "CertificateArn",
    "ParameterValue": "arn:aws:acm:us-east-1:123456789012:certificate/xxx"
  },
  {
    "ParameterKey": "CognitoDomainPrefix",
    "ParameterValue": "my-openwebui-prod"
  },
  {
    "ParameterKey": "DomainName",
    "ParameterValue": "openwebui.example.com"
  },
  {
    "ParameterKey": "AlarmEmail",
    "ParameterValue": "alerts@example.com"
  },
  {
    "ParameterKey": "TemplatesBucket",
    "ParameterValue": "my-openwebui-cfn-templates"
  }
]
```

### Key Parameters to Configure

| Parameter | Description | Example |
|-----------|-------------|---------|
| `EnvironmentName` | Resource prefix | `open-webui-prod` |
| `CertificateArn` | ACM certificate ARN | `arn:aws:acm:...` |
| `CognitoDomainPrefix` | Cognito domain (globally unique) | `my-openwebui-prod` |
| `DomainName` | Your custom domain | `openwebui.example.com` |
| `AlarmEmail` | Email for alerts | `alerts@example.com` |
| `TemplatesBucket` | S3 bucket name | `my-cfn-templates` |
| `TaskCPU` | ECS task CPU | `512` (0.5 vCPU) |
| `TaskMemory` | ECS task memory | `1024` (1 GB) |
| `DesiredCount` | Number of tasks | `1` |

See `examples/parameters-prod.json` for all available parameters.

## Step 5: Validate CloudFormation Template

Before deploying, validate the template:

```bash
./scripts/validate-template.sh
```

Or manually:
```bash
aws cloudformation validate-template \
  --template-body file://cloudformation/main-stack.yaml \
  --region ${AWS_REGION}
```

## Step 6: Deploy the Stack

### Option A: Using Deployment Script

```bash
./scripts/deploy-stack.sh \
  --environment prod \
  --region us-east-1 \
  --parameters my-parameters.json
```

### Option B: Using AWS CLI

```bash
aws cloudformation create-stack \
  --stack-name open-webui-prod \
  --template-body file://cloudformation/main-stack.yaml \
  --parameters file://my-parameters.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ${AWS_REGION} \
  --tags Key=Environment,Value=production Key=Application,Value=OpenWebUI
```

### Monitor Stack Creation

```bash
# Watch stack events
aws cloudformation describe-stack-events \
  --stack-name open-webui-prod \
  --region ${AWS_REGION} \
  --query 'StackEvents[*].[Timestamp,ResourceStatus,ResourceType,LogicalResourceId]' \
  --output table

# Or use the monitoring script
./scripts/monitor-stack.sh open-webui-prod
```

Stack creation takes approximately **15-20 minutes**.

## Step 7: Update Cognito Client Secret

After stack creation, you need to update the Cognito client secret in Secrets Manager:

1. **Get Cognito Client Secret:**
   ```bash
   # Get User Pool Client ID from stack outputs
   CLIENT_ID=$(aws cloudformation describe-stacks \
     --stack-name open-webui-prod \
     --query 'Stacks[0].Outputs[?OutputKey==`CognitoUserPoolClientId`].OutputValue' \
     --output text \
     --region ${AWS_REGION})
   
   # Get User Pool ID
   POOL_ID=$(aws cloudformation describe-stacks \
     --stack-name open-webui-prod \
     --query 'Stacks[0].Outputs[?OutputKey==`CognitoUserPoolId`].OutputValue' \
     --output text \
     --region ${AWS_REGION})
   
   # Get client secret from Cognito
   aws cognito-idp describe-user-pool-client \
     --user-pool-id ${POOL_ID} \
     --client-id ${CLIENT_ID} \
     --query 'UserPoolClient.ClientSecret' \
     --output text \
     --region ${AWS_REGION}
   ```

2. **Update Secrets Manager:**
   ```bash
   # Copy the client secret from above, then:
   aws secretsmanager update-secret \
     --secret-id open-webui-prod/cognito-client-secret \
     --secret-string '{"client_secret":"YOUR_CLIENT_SECRET_HERE"}' \
     --region ${AWS_REGION}
   ```

3. **Restart ECS Tasks** to pick up the new secret:
   ```bash
   # Get cluster and service names
   CLUSTER=$(aws cloudformation describe-stacks \
     --stack-name open-webui-prod \
     --query 'Stacks[0].Outputs[?OutputKey==`ECSClusterName`].OutputValue' \
     --output text \
     --region ${AWS_REGION})
   
   SERVICE=$(aws cloudformation describe-stacks \
     --stack-name open-webui-prod \
     --query 'Stacks[0].Outputs[?OutputKey==`ECSService`].OutputValue' \
     --output text \
     --region ${AWS_REGION})
   
   # Force new deployment
   aws ecs update-service \
     --cluster ${CLUSTER} \
     --service ${SERVICE} \
     --force-new-deployment \
     --region ${AWS_REGION}
   ```

## Step 8: Create Admin User

Create your first admin user in Cognito:

```bash
# Create user
aws cognito-idp admin-create-user \
  --user-pool-id ${POOL_ID} \
  --username admin@example.com \
  --user-attributes Name=email,Value=admin@example.com Name=email_verified,Value=true \
  --temporary-password "TempPass123!" \
  --message-action SUPPRESS \
  --region ${AWS_REGION}

# Add user to Admins group
aws cognito-idp admin-add-user-to-group \
  --user-pool-id ${POOL_ID} \
  --username admin@example.com \
  --group-name Admins \
  --region ${AWS_REGION}
```

## Step 9: Configure DNS (Optional)

If using a custom domain, create a CNAME record:

1. **Get ALB DNS name:**
   ```bash
   ALB_DNS=$(aws cloudformation describe-stacks \
     --stack-name open-webui-prod \
     --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNSName`].OutputValue' \
     --output text \
     --region ${AWS_REGION})
   
   echo "ALB DNS: ${ALB_DNS}"
   ```

2. **Create CNAME record** in your DNS provider:
   ```
   Type: CNAME
   Name: openwebui.example.com
   Value: <ALB_DNS_NAME>
   TTL: 300
   ```

3. **Wait for DNS propagation** (usually 5-30 minutes)

4. **Verify DNS:**
   ```bash
   nslookup openwebui.example.com
   ```

## Step 10: Access Open WebUI

1. **Get the URL:**
   ```bash
   aws cloudformation describe-stacks \
     --stack-name open-webui-prod \
     --query 'Stacks[0].Outputs[?OutputKey==`OpenWebUIURL`].OutputValue' \
     --output text \
     --region ${AWS_REGION}
   ```

2. **Open in browser** and log in with your admin credentials

3. **Change temporary password** on first login

## Post-Deployment Configuration

### View CloudWatch Dashboard

```bash
# Get dashboard URL
aws cloudformation describe-stacks \
  --stack-name open-webui-prod \
  --query 'Stacks[0].Outputs[?OutputKey==`CloudWatchDashboardURL`].OutputValue' \
  --output text \
  --region ${AWS_REGION}
```

### View Application Logs

```bash
# Get log group name
LOG_GROUP=$(aws cloudformation describe-stacks \
  --stack-name open-webui-prod \
  --query 'Stacks[0].Outputs[?OutputKey==`ApplicationLogGroup`].OutputValue' \
  --output text \
  --region ${AWS_REGION})

# Tail logs
aws logs tail ${LOG_GROUP} --follow --region ${AWS_REGION}
```

### Configure Auto-Scaling

Auto-scaling is pre-configured with:
- CPU target: 70%
- Memory target: 80%
- Min tasks: 1 (configurable)
- Max tasks: 4 (configurable)

To adjust, update stack parameters and redeploy.

## Updating the Deployment

### Update Stack Parameters

1. **Modify parameters file:**
   ```bash
   vim my-parameters.json
   ```

2. **Update stack:**
   ```bash
   aws cloudformation update-stack \
     --stack-name open-webui-prod \
     --template-body file://cloudformation/main-stack.yaml \
     --parameters file://my-parameters.json \
     --capabilities CAPABILITY_NAMED_IAM \
     --region ${AWS_REGION}
   ```

### Update Open WebUI Image

To update to a new Open WebUI version:

1. **Update `OpenWebUIImage` parameter:**
   ```json
   {
     "ParameterKey": "OpenWebUIImage",
     "ParameterValue": "ghcr.io/open-webui/open-webui:v0.2.0"
   }
   ```

2. **Update stack** (as shown above)

3. **ECS will perform rolling update** automatically

## Monitoring and Maintenance

### CloudWatch Alarms

The deployment creates alarms for:
- High CPU utilization (>80%)
- High memory utilization (>90%)
- No running tasks
- Unhealthy targets
- High response time (>5s)
- Application errors
- 5XX errors

Alarms send notifications to the email specified in `AlarmEmail` parameter.

### View Metrics

Access CloudWatch dashboard for real-time metrics:
- ECS utilization
- Task counts
- ALB response times
- Request counts and HTTP codes
- Target health

### Backup and Recovery

**EFS Backups:**
- Automatic backups enabled by default
- Retention: 35 days
- Managed by AWS Backup

**Manual Backup:**
```bash
# Create EFS backup
aws backup start-backup-job \
  --backup-vault-name Default \
  --resource-arn <EFS_ARN> \
  --iam-role-arn <BACKUP_ROLE_ARN> \
  --region ${AWS_REGION}
```

## Cost Optimization

### Estimated Monthly Costs

| Service | Configuration | Estimated Cost |
|---------|--------------|----------------|
| ECS Fargate | 1 task, 0.5 vCPU, 1GB | ~$15 |
| ALB | Standard | ~$20 |
| EFS | 10GB storage | ~$3 |
| NAT Gateway | 2 AZs | ~$65 |
| Data Transfer | Variable | ~$10 |
| CloudWatch | Logs + Metrics | ~$5 |
| **Total** | | **~$118/month** |

### Cost Reduction Strategies

1. **Single NAT Gateway** (reduces HA):
   - Modify network template to use one NAT Gateway
   - Saves ~$32/month

2. **EFS Infrequent Access:**
   - Already configured (30-day transition)
   - Saves on storage costs for old data

3. **Fargate Spot:**
   - Use Spot pricing for non-production
   - Saves up to 70% on compute

4. **Scheduled Scaling:**
   - Scale down during off-hours
   - Implement via EventBridge rules

## Troubleshooting

### Stack Creation Fails

1. **Check stack events:**
   ```bash
   aws cloudformation describe-stack-events \
     --stack-name open-webui-prod \
     --region ${AWS_REGION}
   ```

2. **Common issues:**
   - Certificate ARN incorrect or in wrong region
   - Cognito domain prefix not unique
   - Insufficient IAM permissions
   - S3 bucket not accessible

### Tasks Won't Start

1. **Check ECS service events:**
   ```bash
   aws ecs describe-services \
     --cluster ${CLUSTER} \
     --services ${SERVICE} \
     --region ${AWS_REGION}
   ```

2. **Common issues:**
   - EFS mount failures (check security groups)
   - Secrets Manager access denied
   - Image pull failures
   - Insufficient CPU/memory

### Authentication Fails

1. **Verify Cognito client secret updated** in Secrets Manager

2. **Check callback URL** matches exactly

3. **View ECS task logs:**
   ```bash
   aws logs tail /ecs/open-webui-prod/open-webui --follow --region ${AWS_REGION}
   ```

### High Costs

1. **Check NAT Gateway data transfer:**
   ```bash
   aws cloudwatch get-metric-statistics \
     --namespace AWS/NATGateway \
     --metric-name BytesOutToDestination \
     --dimensions Name=NatGatewayId,Value=<NAT_ID> \
     --start-time 2024-01-01T00:00:00Z \
     --end-time 2024-01-31T23:59:59Z \
     --period 86400 \
     --statistics Sum \
     --region ${AWS_REGION}
   ```

2. **Review EFS usage:**
   ```bash
   aws efs describe-file-systems \
     --file-system-id <FS_ID> \
     --region ${AWS_REGION}
   ```

## Deleting the Deployment

⚠️ **Warning:** This will delete all resources and data.

```bash
# Delete stack
aws cloudformation delete-stack \
  --stack-name open-webui-prod \
  --region ${AWS_REGION}

# Monitor deletion
aws cloudformation wait stack-delete-complete \
  --stack-name open-webui-prod \
  --region ${AWS_REGION}

# Clean up S3 bucket (optional)
aws s3 rb s3://${BUCKET_NAME} --force --region ${AWS_REGION}
```

## Security Best Practices

1. **Enable MFA** for Cognito users
2. **Rotate secrets** regularly
3. **Review IAM policies** for least privilege
4. **Enable CloudTrail** for audit logging
5. **Use VPC endpoints** for AWS services (optional)
6. **Regular security updates** for Open WebUI image
7. **Monitor CloudWatch alarms**
8. **Enable AWS GuardDuty** for threat detection

## Next Steps

- **Configure LLM backends** in Open WebUI settings
- **Invite users** via Cognito
- **Set up custom domain** with Route 53
- **Enable WAF** for additional security
- **Configure CloudFront** for CDN (optional)
- **Set up CI/CD** for automated deployments

## Additional Resources

- [Open WebUI Documentation](https://docs.openwebui.com/)
- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [AWS Cognito Documentation](https://docs.aws.amazon.com/cognito/)
- [CloudFormation User Guide](https://docs.aws.amazon.com/cloudformation/)
