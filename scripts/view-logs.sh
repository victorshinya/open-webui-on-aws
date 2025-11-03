#!/bin/bash

# View CloudWatch logs for Open WebUI

set -e

# Colors
BLUE='\033[0;34m'
NC='\033[0m'

# Arguments
STACK_NAME=${1:-}
AWS_REGION=${2:-us-east-1}
LINES=${3:-50}

if [ -z "$STACK_NAME" ]; then
    echo "Usage: $0 STACK_NAME [REGION] [LINES]"
    echo ""
    echo "Example:"
    echo "  $0 open-webui-prod us-east-1 100"
    exit 1
fi

LOG_GROUP="/ecs/${STACK_NAME}/open-webui"

echo "=========================================="
echo "CloudWatch Logs: ${LOG_GROUP}"
echo "=========================================="
echo ""

# Check if log group exists
if ! aws logs describe-log-groups \
    --log-group-name-prefix ${LOG_GROUP} \
    --region ${AWS_REGION} 2>/dev/null | grep -q ${LOG_GROUP}; then
    echo "Log group not found: ${LOG_GROUP}"
    exit 1
fi

# Tail logs
echo -e "${BLUE}Tailing logs (Ctrl+C to stop)...${NC}"
echo ""

aws logs tail ${LOG_GROUP} \
    --follow \
    --format short \
    --region ${AWS_REGION}
