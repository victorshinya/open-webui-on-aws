# Open WebUI AWS Deployment with Cognito Authentication

A comprehensive solution for deploying [Open WebUI](https://github.com/open-webui/open-webui) with AWS Cognito authentication, supporting both local development and AWS cloud deployment.

## Overview

This project provides infrastructure-as-code and configuration for running Open WebUI, a web interface for Large Language Models (LLMs), with the following features:

- **Local Development**: Docker Compose setup for development without AWS costs
- **AWS Deployment**: CloudFormation templates for production-ready infrastructure
- **Cognito Authentication**: Secure OAuth2/OIDC integration with AWS Cognito
- **Persistent Storage**: Data persistence using Docker volumes (local) and EFS (AWS)
- **High Availability**: Multi-AZ deployment with auto-scaling on AWS

## Architecture

### Local Environment
```
Browser → Open WebUI Container → Docker Volume
           ↓
       AWS Cognito (Authentication)
```

### AWS Environment
```
Browser → ALB (HTTPS) → ECS Fargate → Open WebUI Container → EFS Storage
                          ↓
                      AWS Cognito (Authentication)
                          ↓
                      CloudWatch Logs
```

## Quick Start

### Prerequisites

**For Local Development:**
- Docker Engine 20.10+
- Docker Compose 2.0+
- AWS Cognito User Pool (see setup guide below)

**For AWS Deployment:**
- AWS CLI configured with appropriate credentials
- AWS account with permissions to create VPC, ECS, EFS, ALB, Cognito resources
- ACM certificate for your domain (for HTTPS)

### Local Development Setup

1. Clone this repository:
```bash
git clone https://github.com/victorshinya/open-webui-on-aws
cd open-webui-on-aws
```

2. Copy the environment template:
```bash
cp .env.example .env.local
```

3. Configure your Cognito settings in `.env.local`:
```bash
# Edit .env.local with your Cognito User Pool details
OAUTH_CLIENT_ID=your-client-id
OAUTH_CLIENT_SECRET=your-client-secret
COGNITO_USER_POOL_ID=your-user-pool-id
AWS_REGION=us-east-1
```

4. Start Open WebUI:
```bash
docker-compose up -d
```

5. Access Open WebUI at `http://localhost:3000`

### AWS Deployment

See [AWS Deployment Guide](docs/aws-deployment.md) for detailed instructions.

Quick deploy:
```bash
# Validate the CloudFormation template
./scripts/validate-template.sh

# Deploy the stack
./scripts/deploy-stack.sh --environment production --region us-east-1
```

## Project Structure

```
.
├── README.md                          # This file
├── docker-compose.yml                 # Local development configuration
├── .env.example                       # Environment variables template
├── cloudformation/                    # CloudFormation templates
│   ├── main-stack.yaml               # Master template
│   ├── network.yaml                  # VPC and networking resources
│   ├── cognito.yaml                  # Cognito User Pool configuration
│   ├── storage.yaml                  # EFS file system
│   ├── compute.yaml                  # ECS cluster and services
│   ├── loadbalancer.yaml             # Application Load Balancer
│   └── monitoring.yaml               # CloudWatch logs and alarms
├── scripts/                          # Helper scripts
│   ├── deploy-stack.sh              # Deploy CloudFormation stack
│   ├── validate-template.sh         # Validate templates
│   ├── delete-stack.sh              # Clean up resources
│   └── local-setup.sh               # Local environment setup
├── docs/                            # Documentation
│   ├── local-deployment.md          # Local setup guide
│   ├── aws-deployment.md            # AWS deployment guide
│   ├── cognito-setup.md             # Cognito configuration
│   └── troubleshooting.md           # Common issues and solutions
└── examples/                        # Configuration examples
    ├── parameters-dev.json          # Development parameters
    └── parameters-prod.json         # Production parameters
```

## Configuration

### Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `OAUTH_CLIENT_ID` | Cognito App Client ID | Yes | - |
| `OAUTH_CLIENT_SECRET` | Cognito App Client Secret | Yes | - |
| `COGNITO_USER_POOL_ID` | Cognito User Pool ID | Yes | - |
| `AWS_REGION` | AWS Region | Yes | us-east-1 |
| `OAUTH_REDIRECT_URI` | OAuth callback URL | Yes | http://localhost:3000/oauth/callback |
| `DATA_DIR` | Data storage directory | No | /app/data |

See `.env.example` for complete configuration options.

## Documentation

- [Local Deployment Guide](docs/local-deployment.md) - Set up Open WebUI locally
- [AWS Deployment Guide](docs/aws-deployment.md) - Deploy to AWS with CloudFormation
- [Architecture Documentation](docs/architecture.md) - Detailed architecture diagrams and decisions
- [Cognito Setup Guide](docs/cognito-setup.md) - Configure AWS Cognito authentication
- [Troubleshooting Guide](docs/troubleshooting.md) - Common issues and solutions
- [Parameter Examples](examples/README.md) - CloudFormation parameter configurations

## Security

This deployment follows AWS security best practices:

- ✅ HTTPS-only external access
- ✅ Private subnets for compute resources
- ✅ Encryption at rest (EFS, CloudWatch Logs)
- ✅ IAM roles with least-privilege permissions
- ✅ Security groups with minimal required access
- ✅ JWT token validation for authentication
- ✅ Secrets stored in AWS Secrets Manager

## Cost Estimation

**Local Development:** Free (no AWS costs)

**AWS Deployment (estimated monthly costs):**
- ECS Fargate (1 task, 0.5 vCPU, 1GB RAM): ~$15
- Application Load Balancer: ~$20
- EFS Storage (10GB): ~$3
- Data Transfer: Variable
- CloudWatch Logs: ~$5
- **Total: ~$43/month** (excluding data transfer)

Use cost allocation tags to track actual usage.

## Support

For issues and questions:
- Check the [Troubleshooting Guide](docs/troubleshooting.md)
- Review [Open WebUI Documentation](https://docs.openwebui.com/)
- Review [AWS Cognito Documentation](https://docs.aws.amazon.com/cognito/)

## License

MIT License

Copyright (c) 2025 Victor Shinya

## Contributing

Contributions are welcome! Please submit pull requests or open issues for bugs and feature requests.
