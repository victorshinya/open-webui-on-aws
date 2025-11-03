#!/bin/bash

# Get CloudFormation stack outputs

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
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
echo "Stack Outputs: ${STACK_NAME}"
echo "=========================================="
echo ""

# Check if stack exists
if ! aws cloudformation describe-stacks \
    --stack-name ${STACK_NAME} \
    --region ${AWS_REGION} &> /dev/null; then
    echo "Stack not found: ${STACK_NAME}"
    exit 1
fi

# Get outputs in table format
aws cloudformation describe-stacks \
    --stack-name ${STACK_NAME} \
    --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue,Description]' \
    --output table \
    --region ${AWS_REGION}

echo ""
echo "=========================================="
echo "Quick Access"
echo "=========================================="
echo ""

# Get specific outputs
WEBUI_URL=$(aws cloudformation describe-stacks \
    --stack-name ${STACK_NAME} \
    --query 'Stacks[0].Outputs[?OutputKey==`OpenWebUIURL`].OutputValue' \
    --output text \
    --region ${AWS_REGION} 2>/dev/null || echo "N/A")

DASHBOARD_URL=$(aws cloudformation describe-stacks \
    --stack-name ${STACK_NAME} \
    --query 'Stacks[0].Outputs[?OutputKey==`CloudWatchDashboardURL`].OutputValue' \
    --output text \
    --region ${AWS_REGION} 2>/dev/null || echo "N/A")

USER_POOL_ID=$(aws cloudformation describe-stacks \
    --stack-name ${STACK_NAME} \
    --query 'Stacks[0].Outputs[?OutputKey==`CognitoUserPoolId`].OutputValue' \
    --output text \
    --region ${AWS_REGION} 2>/dev/null || echo "N/A")

echo -e "${BLUE}Open WebUI:${NC}"
echo "  ${WEBUI_URL}"
echo ""
echo -e "${BLUE}CloudWatch Dashboard:${NC}"
echo "  ${DASHBOARD_URL}"
echo ""
echo -e "${BLUE}Cognito User Pool ID:${NC}"
echo "  ${USER_POOL_ID}"
echo ""
