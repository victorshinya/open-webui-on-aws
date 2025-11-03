#!/bin/bash

# View CloudFormation stack events

set -e

# Arguments
STACK_NAME=${1:-}
AWS_REGION=${2:-us-east-1}
LIMIT=${3:-20}

if [ -z "$STACK_NAME" ]; then
    echo "Usage: $0 STACK_NAME [REGION] [LIMIT]"
    echo ""
    echo "Example:"
    echo "  $0 open-webui-prod us-east-1 50"
    exit 1
fi

echo "=========================================="
echo "Stack Events: ${STACK_NAME}"
echo "Showing last ${LIMIT} events"
echo "=========================================="
echo ""

# Check if stack exists
if ! aws cloudformation describe-stacks \
    --stack-name ${STACK_NAME} \
    --region ${AWS_REGION} &> /dev/null; then
    echo "Stack not found: ${STACK_NAME}"
    exit 1
fi

# Get events
aws cloudformation describe-stack-events \
    --stack-name ${STACK_NAME} \
    --region ${AWS_REGION} \
    --max-items ${LIMIT} \
    --query 'StackEvents[*].[Timestamp,ResourceStatus,ResourceType,LogicalResourceId,ResourceStatusReason]' \
    --output table
