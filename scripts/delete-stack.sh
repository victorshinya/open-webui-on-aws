#!/bin/bash

# Delete CloudFormation stack

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Arguments
STACK_NAME=${1:-}
AWS_REGION=${2:-us-east-1}

if [ -z "$STACK_NAME" ]; then
    echo "Usage: $0 STACK_NAME [REGION]"
    echo ""
    echo "Example:"
    echo "  $0 open-webui-prod us-east-1"
    exit 1
fi

echo "=========================================="
echo "Delete CloudFormation Stack"
echo "=========================================="
echo ""
echo -e "${RED}WARNING: This will delete all resources!${NC}"
echo ""
echo "Stack Name: ${STACK_NAME}"
echo "Region:     ${AWS_REGION}"
echo ""
echo "This will delete:"
echo "  - VPC and all networking resources"
echo "  - ECS cluster and tasks"
echo "  - EFS file system and ALL DATA"
echo "  - Load balancer"
echo "  - Cognito user pool and users"
echo "  - CloudWatch logs and alarms"
echo "  - All other associated resources"
echo ""

# Check if stack exists
if ! aws cloudformation describe-stacks \
    --stack-name ${STACK_NAME} \
    --region ${AWS_REGION} &> /dev/null; then
    echo -e "${RED}✗${NC} Stack not found: ${STACK_NAME}"
    exit 1
fi

# Confirmation
read -p "Type 'DELETE' to confirm deletion: " CONFIRM

if [ "$CONFIRM" != "DELETE" ]; then
    echo "Deletion cancelled"
    exit 0
fi

echo ""
echo "Deleting stack..."

# Delete stack
aws cloudformation delete-stack \
    --stack-name ${STACK_NAME} \
    --region ${AWS_REGION}

echo -e "${GREEN}✓${NC} Stack deletion initiated"
echo ""
echo "Monitor progress:"
echo "  aws cloudformation describe-stack-events --stack-name ${STACK_NAME} --region ${AWS_REGION}"
echo ""
echo "Or wait for completion:"
echo "  aws cloudformation wait stack-delete-complete --stack-name ${STACK_NAME} --region ${AWS_REGION}"
echo ""
