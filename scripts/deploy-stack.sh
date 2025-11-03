#!/bin/bash

# Deploy CloudFormation stack for Open WebUI

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
STACK_NAME=""
PARAMETERS_FILE=""
AWS_REGION="us-east-1"
TEMPLATES_BUCKET=""
ENVIRONMENT=""
AWS_PROFILE=""

# Usage function
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -n, --name NAME           Stack name (default: open-webui-ENVIRONMENT)"
    echo "  -e, --environment ENV     Environment name (required)"
    echo "  -r, --region REGION       AWS region (default: us-east-1)"
    echo "  -p, --parameters FILE     Parameters file (default: examples/parameters-ENV.json)"
    echo "  -b, --bucket BUCKET       S3 bucket for templates (required)"
    echo "  --profile PROFILE         AWS CLI profile name"
    echo "  -h, --help                Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --environment prod --region us-east-1 --bucket my-cfn-templates"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            STACK_NAME="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -r|--region)
            AWS_REGION="$2"
            shift 2
            ;;
        -p|--parameters)
            PARAMETERS_FILE="$2"
            shift 2
            ;;
        -b|--bucket)
            TEMPLATES_BUCKET="$2"
            shift 2
            ;;
        --profile)
            AWS_PROFILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Validate required parameters
if [ -z "$ENVIRONMENT" ]; then
    echo -e "${RED}Error: Environment is required${NC}"
    usage
fi

# Set defaults based on environment
if [ -z "$STACK_NAME" ]; then
    STACK_NAME="open-webui-${ENVIRONMENT}"
fi

if [ -z "$PARAMETERS_FILE" ]; then
    PARAMETERS_FILE="examples/parameters-${ENVIRONMENT}.json"
fi

echo "=========================================="
echo "Open WebUI CloudFormation Deployment"
echo "=========================================="
echo ""
echo "Stack Name:      ${STACK_NAME}"
echo "Environment:     ${ENVIRONMENT}"
echo "Region:          ${AWS_REGION}"
echo "Parameters File: ${PARAMETERS_FILE}"
echo "Templates Bucket: ${TEMPLATES_BUCKET}"
if [ -n "$AWS_PROFILE" ]; then
    echo "AWS Profile:     ${AWS_PROFILE}"
fi
echo ""

# Build AWS CLI profile flag
PROFILE_FLAG=""
if [ -n "$AWS_PROFILE" ]; then
    PROFILE_FLAG="--profile ${AWS_PROFILE}"
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}✗${NC} AWS CLI is not installed"
    exit 1
fi

# Check if parameters file exists
if [ ! -f "$PARAMETERS_FILE" ]; then
    echo -e "${RED}✗${NC} Parameters file not found: ${PARAMETERS_FILE}"
    exit 1
fi

# Check if templates bucket is provided
if [ -z "$TEMPLATES_BUCKET" ]; then
    echo -e "${RED}✗${NC} Templates bucket is required"
    echo "Use --bucket option to specify S3 bucket name"
    exit 1
fi

# Validate templates
echo -e "${BLUE}Step 1: Validating templates...${NC}"
./scripts/validate-template.sh
echo ""

# Upload templates to S3
echo -e "${BLUE}Step 2: Uploading templates to S3...${NC}"
aws s3 sync cloudformation/ s3://${TEMPLATES_BUCKET}/ \
    --exclude "main-stack.yaml" \
    --region ${AWS_REGION} \
    ${PROFILE_FLAG}
echo -e "${GREEN}✓${NC} Templates uploaded"
echo ""

# Check if stack exists
echo -e "${BLUE}Step 3: Checking if stack exists...${NC}"
if aws cloudformation describe-stacks \
    --stack-name ${STACK_NAME} \
    --region ${AWS_REGION} \
    ${PROFILE_FLAG} &> /dev/null; then
    STACK_EXISTS=true
    echo -e "${YELLOW}⚠${NC} Stack already exists, will update"
else
    STACK_EXISTS=false
    echo -e "${GREEN}✓${NC} Stack does not exist, will create"
fi
echo ""

# Deploy stack
if [ "$STACK_EXISTS" = true ]; then
    echo -e "${BLUE}Step 4: Updating stack...${NC}"
    aws cloudformation update-stack \
        --stack-name ${STACK_NAME} \
        --template-body file://cloudformation/main-stack.yaml \
        --parameters file://${PARAMETERS_FILE} \
        --capabilities CAPABILITY_NAMED_IAM \
        --region ${AWS_REGION} \
        --tags Key=Environment,Value=${ENVIRONMENT} Key=Application,Value=OpenWebUI \
        ${PROFILE_FLAG}
    
    echo ""
    echo -e "${GREEN}✓${NC} Stack update initiated"
    echo ""
    echo "Monitor progress:"
    echo "  ./scripts/monitor-stack.sh ${STACK_NAME} ${AWS_REGION}"
    echo ""
    echo "Or in AWS Console:"
    echo "  https://console.aws.amazon.com/cloudformation/home?region=${AWS_REGION}#/stacks"
else
    echo -e "${BLUE}Step 4: Creating stack...${NC}"
    aws cloudformation create-stack \
        --stack-name ${STACK_NAME} \
        --template-body file://cloudformation/main-stack.yaml \
        --parameters file://${PARAMETERS_FILE} \
        --capabilities CAPABILITY_NAMED_IAM \
        --region ${AWS_REGION} \
        --disable-rollback \
        --tags Key=Environment,Value=${ENVIRONMENT} Key=Application,Value=OpenWebUI \
        ${PROFILE_FLAG}
    
    echo ""
    echo -e "${GREEN}✓${NC} Stack creation initiated"
    echo ""
    echo "Monitor progress:"
    echo "  ./scripts/monitor-stack.sh ${STACK_NAME} ${AWS_REGION}"
    echo ""
    echo "Or in AWS Console:"
    echo "  https://console.aws.amazon.com/cloudformation/home?region=${AWS_REGION}#/stacks"
fi

echo ""
echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo ""
echo "1. Wait for stack creation to complete (15-20 minutes)"
echo "2. Update Cognito client secret in Secrets Manager"
echo "3. Create admin user in Cognito"
echo "4. Configure DNS (if using custom domain)"
echo "5. Access Open WebUI"
echo ""
echo "See docs/aws-deployment.md for detailed instructions"
echo ""
