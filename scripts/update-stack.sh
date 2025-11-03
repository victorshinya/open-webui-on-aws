#!/bin/bash

# Update existing CloudFormation stack

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Arguments
STACK_NAME=${1:-}
PARAMETERS_FILE=${2:-}
AWS_REGION=${3:-us-east-1}

if [ -z "$STACK_NAME" ]; then
    echo "Usage: $0 STACK_NAME [PARAMETERS_FILE] [REGION]"
    echo ""
    echo "Example:"
    echo "  $0 open-webui-prod my-parameters.json us-east-1"
    exit 1
fi

echo "=========================================="
echo "Update CloudFormation Stack"
echo "=========================================="
echo ""
echo "Stack Name: ${STACK_NAME}"
echo "Region:     ${AWS_REGION}"
if [ -n "$PARAMETERS_FILE" ]; then
    echo "Parameters: ${PARAMETERS_FILE}"
fi
echo ""

# Check if stack exists
if ! aws cloudformation describe-stacks \
    --stack-name ${STACK_NAME} \
    --region ${AWS_REGION} &> /dev/null; then
    echo -e "${RED}✗${NC} Stack not found: ${STACK_NAME}"
    exit 1
fi

# Validate template
echo -e "${BLUE}Validating template...${NC}"
./scripts/validate-template.sh
echo ""

# Build update command
UPDATE_CMD="aws cloudformation update-stack \
    --stack-name ${STACK_NAME} \
    --template-body file://cloudformation/main-stack.yaml \
    --capabilities CAPABILITY_NAMED_IAM \
    --region ${AWS_REGION}"

if [ -n "$PARAMETERS_FILE" ]; then
    if [ ! -f "$PARAMETERS_FILE" ]; then
        echo -e "${RED}✗${NC} Parameters file not found: ${PARAMETERS_FILE}"
        exit 1
    fi
    UPDATE_CMD="${UPDATE_CMD} --parameters file://${PARAMETERS_FILE}"
else
    UPDATE_CMD="${UPDATE_CMD} --use-previous-template"
fi

# Execute update
echo -e "${BLUE}Updating stack...${NC}"
if eval $UPDATE_CMD; then
    echo -e "${GREEN}✓${NC} Stack update initiated"
    echo ""
    echo "Monitor progress:"
    echo "  ./scripts/monitor-stack.sh ${STACK_NAME} ${AWS_REGION}"
else
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 254 ]; then
        echo -e "${YELLOW}⚠${NC} No updates to perform"
    else
        echo -e "${RED}✗${NC} Stack update failed"
        exit $EXIT_CODE
    fi
fi
