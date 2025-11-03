# CloudFormation Parameter Examples

This directory contains example parameter files for different deployment environments.

## Files

- **parameters-dev.json** - Development environment configuration
- **parameters-prod.json** - Production environment configuration

## Usage

1. **Copy the appropriate example:**
   ```bash
   cp examples/parameters-prod.json my-parameters.json
   ```

2. **Edit the parameters:**
   ```bash
   vim my-parameters.json
   ```

3. **Deploy with your parameters:**
   ```bash
   ./scripts/deploy-stack.sh \
     --environment prod \
     --region us-east-1 \
     --parameters my-parameters.json \
     --bucket my-cfn-templates
   ```

## Parameter Descriptions

### Environment Configuration

| Parameter | Description | Dev Example | Prod Example |
|-----------|-------------|-------------|--------------|
| `EnvironmentName` | Resource prefix | `open-webui-dev` | `open-webui-prod` |
| `AlarmEmail` | Email for alerts | `dev-alerts@example.com` | `prod-alerts@example.com` |

### Network Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `VpcCIDR` | VPC CIDR block | `10.0.0.0/16` |
| `PublicSubnet1CIDR` | Public subnet AZ1 | `10.0.1.0/24` |
| `PublicSubnet2CIDR` | Public subnet AZ2 | `10.0.2.0/24` |
| `PrivateSubnet1CIDR` | Private subnet AZ1 | `10.0.11.0/24` |
| `PrivateSubnet2CIDR` | Private subnet AZ2 | `10.0.12.0/24` |

### Cognito Configuration

| Parameter | Description | Dev Example | Prod Example |
|-----------|-------------|-------------|--------------|
| `CognitoDomainPrefix` | Cognito domain (globally unique) | `my-openwebui-dev` | `my-openwebui-prod` |
| `EnableMFA` | MFA setting | `OPTIONAL` | `OPTIONAL` or `ON` |
| `PasswordMinimumLength` | Min password length | `8` | `12` |

### SSL/TLS Configuration

| Parameter | Description | Required |
|-----------|-------------|----------|
| `CertificateArn` | ACM certificate ARN | Yes |
| `DomainName` | Custom domain name | Optional |

**Note:** Certificate must be in the same region as deployment.

### Compute Configuration

| Parameter | Description | Dev | Prod |
|-----------|-------------|-----|------|
| `OpenWebUIImage` | Docker image | `ghcr.io/open-webui/open-webui:main` | Same or specific version |
| `TaskCPU` | CPU units (256=0.25 vCPU) | `256` | `512` |
| `TaskMemory` | Memory in MB | `512` | `1024` |
| `DesiredCount` | Number of tasks | `1` | `2` |
| `MinCapacity` | Min tasks for auto-scaling | `1` | `2` |
| `MaxCapacity` | Max tasks for auto-scaling | `2` | `4` |

**CPU/Memory Combinations:**
- 256 CPU: 512, 1024, 2048 MB
- 512 CPU: 1024, 2048, 3072, 4096 MB
- 1024 CPU: 2048, 3072, 4096, 5120, 6144, 7168, 8192 MB
- 2048 CPU: 4096-16384 MB (1024 MB increments)
- 4096 CPU: 8192-30720 MB (1024 MB increments)

### Storage Configuration

| Parameter | Description | Options |
|-----------|-------------|---------|
| `PerformanceMode` | EFS performance | `generalPurpose`, `maxIO` |
| `ThroughputMode` | EFS throughput | `bursting`, `elastic` |
| `TransitionToIA` | Days to IA storage | `NONE`, `7`, `14`, `30`, `60`, `90` |
| `EnableBackup` | Enable EFS backups | `true`, `false` |

### Monitoring Configuration

| Parameter | Description | Dev | Prod |
|-----------|-------------|-----|------|
| `LogRetentionDays` | CloudWatch log retention | `7` | `30` or `90` |

### Template Storage

| Parameter | Description | Required |
|-----------|-------------|----------|
| `TemplatesBucket` | S3 bucket for templates | Yes |

## Environment-Specific Recommendations

### Development Environment

**Characteristics:**
- Lower cost
- Minimal redundancy
- Shorter log retention
- No backups

**Recommended Settings:**
- TaskCPU: `256` (0.25 vCPU)
- TaskMemory: `512` MB
- DesiredCount: `1`
- EnableBackup: `false`
- LogRetentionDays: `7`

**Estimated Cost:** ~$60/month

### Production Environment

**Characteristics:**
- High availability
- Auto-scaling enabled
- Longer log retention
- Automatic backups

**Recommended Settings:**
- TaskCPU: `512` (0.5 vCPU) or higher
- TaskMemory: `1024` MB or higher
- DesiredCount: `2` (for HA)
- MinCapacity: `2`
- MaxCapacity: `4` or higher
- EnableBackup: `true`
- LogRetentionDays: `30` or `90`
- EnableMFA: `ON` (recommended)
- PasswordMinimumLength: `12` or higher

**Estimated Cost:** ~$120-150/month

## Required Changes

Before deploying, you **must** update these parameters:

1. **CertificateArn** - Your ACM certificate ARN
2. **CognitoDomainPrefix** - Must be globally unique
3. **DomainName** - Your custom domain (or leave empty to use ALB DNS)
4. **AlarmEmail** - Your email for alerts
5. **TemplatesBucket** - Your S3 bucket name

## Optional Customizations

### Using Specific Open WebUI Version

Instead of `:main`, use a specific version:
```json
{
  "ParameterKey": "OpenWebUIImage",
  "ParameterValue": "ghcr.io/open-webui/open-webui:v0.2.0"
}
```

### Different AWS Regions

The examples use `us-east-1`. For other regions:
1. Ensure your ACM certificate is in the target region
2. Update the region in deployment commands
3. Certificate ARN will be different per region

### Custom VPC CIDR

If `10.0.0.0/16` conflicts with existing networks:
```json
{
  "ParameterKey": "VpcCIDR",
  "ParameterValue": "172.16.0.0/16"
},
{
  "ParameterKey": "PublicSubnet1CIDR",
  "ParameterValue": "172.16.1.0/24"
},
...
```

## Validation

Validate your parameters before deployment:

```bash
# Check JSON syntax
cat my-parameters.json | jq .

# Validate CloudFormation template
./scripts/validate-template.sh
```

## Security Notes

- Never commit parameter files with real values to version control
- Add `*-parameters.json` to `.gitignore` (except examples)
- Store sensitive values in AWS Secrets Manager
- Use strong, unique Cognito domain prefixes
- Enable MFA for production environments

## Getting Help

For more information:
- [AWS Deployment Guide](../docs/aws-deployment.md)
- [CloudFormation Parameters Documentation](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/parameters-section-structure.html)
