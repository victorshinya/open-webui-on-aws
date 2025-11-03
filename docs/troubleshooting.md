# Troubleshooting Guide

This guide helps you diagnose and resolve common issues with Open WebUI deployment.

## Quick Diagnostics

### Check Overall Health

```bash
# Test deployment
./scripts/test-deployment.sh open-webui-prod us-east-1

# View stack status
aws cloudformation describe-stacks --stack-name open-webui-prod --region us-east-1

# View recent events
./scripts/view-stack-events.sh open-webui-prod us-east-1
```

### View Logs

```bash
# Tail application logs
./scripts/view-logs.sh open-webui-prod us-east-1

# View specific log stream
aws logs tail /ecs/open-webui-prod/open-webui --follow --region us-east-1
```

## Common Issues

### 1. Stack Creation Fails

#### Symptom
CloudFormation stack creation fails with errors.

#### Common Causes

**Certificate ARN Invalid:**
```
Error: Certificate not found or invalid
```
**Solution:**
- Verify certificate exists in the same region
- Check ARN format: `arn:aws:acm:REGION:ACCOUNT:certificate/ID`
- Ensure certificate is validated and issued

**Cognito Domain Not Unique:**
```
Error: Domain prefix already exists
```
**Solution:**
- Choose a different `CognitoDomainPrefix`
- Domain must be globally unique across all AWS accounts

**Insufficient Permissions:**
```
Error: User is not authorized to perform: ACTION
```
**Solution:**
- Verify IAM permissions for CloudFormation, VPC, ECS, EFS, Cognito, etc.
- See [AWS Deployment Guide](aws-deployment.md) for required permissions

**S3 Bucket Not Accessible:**
```
Error: Unable to fetch template from S3
```
**Solution:**
- Verify bucket exists and templates are uploaded
- Check bucket permissions
- Ensure bucket is in the same region

### 2. ECS Tasks Won't Start

#### Symptom
ECS service shows 0 running tasks or tasks keep restarting.

#### Diagnosis

```bash
# Check service status
aws ecs describe-services \
  --cluster open-webui-prod-cluster \
  --services open-webui-prod-service \
  --region us-east-1

# Check task status
aws ecs list-tasks \
  --cluster open-webui-prod-cluster \
  --service-name open-webui-prod-service \
  --region us-east-1

# Describe stopped tasks
aws ecs describe-tasks \
  --cluster open-webui-prod-cluster \
  --tasks TASK_ARN \
  --region us-east-1
```

#### Common Causes

**EFS Mount Failure:**
```
Error: Failed to mount EFS
```
**Solution:**
- Check EFS security group allows NFS (2049) from ECS security group
- Verify EFS mount targets exist in private subnets
- Check EFS file system is in "available" state

**Secrets Manager Access Denied:**
```
Error: Unable to retrieve secret
```
**Solution:**
- Verify Cognito client secret is updated in Secrets Manager
- Check task execution role has `secretsmanager:GetSecretValue` permission
- Ensure secret ARN is correct in task definition

**Image Pull Failure:**
```
Error: CannotPullContainerError
```
**Solution:**
- Verify image name is correct: `ghcr.io/open-webui/open-webui:main`
- Check internet connectivity through NAT Gateway
- Verify task execution role has ECR permissions (if using ECR)

**Insufficient CPU/Memory:**
```
Error: Task failed to start due to resource constraints
```
**Solution:**
- Increase `TaskCPU` and `TaskMemory` parameters
- Check ECS cluster capacity
- Review task definition resource requirements

### 3. Authentication Fails

#### Symptom
Users cannot log in or are redirected incorrectly.

#### Diagnosis

```bash
# Check Cognito configuration
aws cognito-idp describe-user-pool \
  --user-pool-id us-east-1_xxxxx \
  --region us-east-1

# Check app client
aws cognito-idp describe-user-pool-client \
  --user-pool-id us-east-1_xxxxx \
  --client-id CLIENT_ID \
  --region us-east-1

# View container logs for auth errors
./scripts/view-logs.sh open-webui-prod us-east-1 | grep -i auth
```

#### Common Causes

**Client Secret Not Updated:**
```
Error: Invalid client credentials
```
**Solution:**
1. Get client secret from Cognito
2. Update Secrets Manager secret
3. Restart ECS tasks

```bash
# Get secret
aws cognito-idp describe-user-pool-client \
  --user-pool-id POOL_ID \
  --client-id CLIENT_ID \
  --query 'UserPoolClient.ClientSecret' \
  --output text

# Update Secrets Manager
aws secretsmanager update-secret \
  --secret-id open-webui-prod/cognito-client-secret \
  --secret-string '{"client_secret":"YOUR_SECRET"}' \
  --region us-east-1

# Force new deployment
aws ecs update-service \
  --cluster CLUSTER \
  --service SERVICE \
  --force-new-deployment \
  --region us-east-1
```

**Callback URL Mismatch:**
```
Error: Redirect URI mismatch
```
**Solution:**
- Verify callback URL in Cognito matches exactly
- Format: `https://your-domain.com/oauth/callback`
- Check for trailing slashes, http vs https

**Missing OAuth Scopes:**
```
Error: Insufficient scopes
```
**Solution:**
- Ensure app client has `openid`, `email`, `profile` scopes
- Update app client configuration in Cognito

### 4. ALB Health Checks Failing

#### Symptom
ALB shows unhealthy targets, 503 errors.

#### Diagnosis

```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn TARGET_GROUP_ARN \
  --region us-east-1

# Check ALB logs (if enabled)
aws s3 ls s3://YOUR_BUCKET/open-webui-prod-alb/
```

#### Common Causes

**Container Not Responding:**
```
Health check failed: Connection refused
```
**Solution:**
- Check container is running: `docker ps` equivalent in ECS
- Verify health check path `/health` is correct
- Check container logs for startup errors
- Increase health check grace period

**Security Group Misconfiguration:**
```
Health check failed: Timeout
```
**Solution:**
- Verify ALB security group allows traffic to ECS security group on port 8080
- Check ECS security group allows traffic from ALB
- Verify network ACLs allow traffic

**Container Startup Slow:**
```
Health check failed during startup
```
**Solution:**
- Increase `HealthCheckGracePeriodSeconds` in ECS service
- Check container logs for slow initialization
- Consider increasing task resources

### 5. Data Not Persisting

#### Symptom
Chat history, models, or settings lost after container restart.

#### Diagnosis

```bash
# Check EFS status
aws efs describe-file-systems \
  --file-system-id fs-xxxxx \
  --region us-east-1

# Check mount targets
aws efs describe-mount-targets \
  --file-system-id fs-xxxxx \
  --region us-east-1

# Check task definition volume configuration
aws ecs describe-task-definition \
  --task-definition open-webui-prod-open-webui \
  --region us-east-1
```

#### Common Causes

**EFS Not Mounted:**
```
Error: Data directory not accessible
```
**Solution:**
- Verify EFS volume is defined in task definition
- Check mount point is `/mnt/efs`
- Verify `DATA_DIR` environment variable points to `/mnt/efs/data`

**Permission Issues:**
```
Error: Permission denied writing to EFS
```
**Solution:**
- Check EFS access point POSIX permissions (1000:1000)
- Verify task role has EFS permissions
- Check file system policy

### 6. High Costs

#### Symptom
AWS bill higher than expected.

#### Diagnosis

```bash
# Check NAT Gateway data transfer
aws cloudwatch get-metric-statistics \
  --namespace AWS/NATGateway \
  --metric-name BytesOutToDestination \
  --dimensions Name=NatGatewayId,Value=nat-xxxxx \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-31T23:59:59Z \
  --period 86400 \
  --statistics Sum \
  --region us-east-1

# Check ECS task count
aws ecs describe-services \
  --cluster CLUSTER \
  --services SERVICE \
  --query 'services[0].runningCount' \
  --region us-east-1

# Check EFS usage
aws efs describe-file-systems \
  --file-system-id fs-xxxxx \
  --query 'FileSystems[0].SizeInBytes' \
  --region us-east-1
```

#### Common Causes

**NAT Gateway Data Transfer:**
- Most expensive component (~$0.045/GB)
- **Solution:** Minimize outbound traffic, use VPC endpoints for AWS services

**Multiple Running Tasks:**
- Auto-scaling may have scaled up
- **Solution:** Review auto-scaling policies, adjust thresholds

**EFS Storage:**
- Large model files
- **Solution:** Enable lifecycle policies, clean up unused data

**ALB Hours:**
- Charged per hour
- **Solution:** Consider using single ALB for multiple applications

### 7. Performance Issues

#### Symptom
Slow response times, timeouts.

#### Diagnosis

```bash
# Check CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ClusterName,Value=CLUSTER Name=ServiceName,Value=SERVICE \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --region us-east-1

# Check ALB response time
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=LOAD_BALANCER \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --region us-east-1
```

#### Common Causes

**Insufficient Resources:**
- High CPU/memory utilization
- **Solution:** Increase task CPU/memory, scale horizontally

**EFS Throughput:**
- Bursting mode exhausted
- **Solution:** Switch to elastic throughput mode

**Database Locks:**
- SQLite contention with multiple tasks
- **Solution:** Consider external database for multi-task deployments

### 8. SSL/TLS Certificate Issues

#### Symptom
HTTPS not working, certificate errors.

#### Diagnosis

```bash
# Check certificate status
aws acm describe-certificate \
  --certificate-arn CERT_ARN \
  --region us-east-1

# Test SSL
openssl s_client -connect your-domain.com:443 -servername your-domain.com
```

#### Common Causes

**Certificate Not Validated:**
```
Error: Certificate pending validation
```
**Solution:**
- Complete DNS validation
- Add CNAME records to your DNS
- Wait for validation (5-30 minutes)

**Wrong Region:**
```
Error: Certificate not found
```
**Solution:**
- Certificate must be in same region as ALB
- Request new certificate in correct region

**Domain Mismatch:**
```
Error: Certificate doesn't match domain
```
**Solution:**
- Ensure certificate covers your domain
- Use wildcard certificate for subdomains

## Local Development Issues

### Docker Issues

**Port Already in Use:**
```bash
# Find process using port
lsof -i :3000

# Kill process
kill -9 PID

# Or change port in .env.local
PORT=8080
```

**Container Won't Start:**
```bash
# Check logs
docker-compose logs open-webui

# Restart with fresh state
./scripts/reset.sh
./scripts/start.sh
```

**Volume Permission Issues:**
```bash
# Check volume
docker volume inspect open-webui-data

# Remove and recreate
docker volume rm open-webui-data
docker-compose up -d
```

## Getting More Help

### Useful Commands

```bash
# Complete diagnostic
./scripts/test-deployment.sh STACK_NAME REGION

# Watch logs in real-time
./scripts/view-logs.sh STACK_NAME REGION

# Check all stack events
./scripts/view-stack-events.sh STACK_NAME REGION 100

# Get stack outputs
./scripts/get-stack-outputs.sh STACK_NAME REGION
```

### AWS Support Resources

- [AWS Support Center](https://console.aws.amazon.com/support/)
- [ECS Troubleshooting](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/troubleshooting.html)
- [Cognito Troubleshooting](https://docs.aws.amazon.com/cognito/latest/developerguide/troubleshooting.html)
- [CloudFormation Troubleshooting](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/troubleshooting.html)

### Community Resources

- [Open WebUI Documentation](https://docs.openwebui.com/)
- [Open WebUI GitHub Issues](https://github.com/open-webui/open-webui/issues)
- [AWS re:Post](https://repost.aws/)

## Preventive Measures

### Regular Maintenance

1. **Monitor CloudWatch Alarms** - Set up email notifications
2. **Review Logs Weekly** - Check for errors and warnings
3. **Update Open WebUI** - Keep container image up to date
4. **Rotate Secrets** - Change Cognito client secret periodically
5. **Review Costs** - Check AWS Cost Explorer monthly
6. **Test Backups** - Verify EFS backups are working
7. **Security Updates** - Apply AWS security patches

### Best Practices

- Enable CloudTrail for audit logging
- Use AWS Config for compliance monitoring
- Set up AWS Budgets for cost alerts
- Document any custom configurations
- Test disaster recovery procedures
- Keep parameter files backed up
- Use version control for infrastructure code
