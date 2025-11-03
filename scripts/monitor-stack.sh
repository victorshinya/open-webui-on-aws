#!/bin/bash

# Monitor CloudFormation stack creation/update

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
STACK_NAME=""
AWS_REGION="us-east-1"
AWS_PROFILE=""

# Usage function
usage() {
    echo "Usage: $0 STACK_NAME [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -r, --region REGION       AWS region (default: us-east-1)"
    echo "  --profile PROFILE         AWS CLI profile name"
    echo "  -h, --help                Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 open-webui-prod --region us-east-1 --profile ag"
    exit 1
}

# Parse arguments
if [ $# -eq 0 ]; then
    usage
fi

STACK_NAME="$1"
shift

while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--region)
            AWS_REGION="$2"
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

# Build AWS CLI profile flag
PROFILE_FLAG=""
if [ -n "$AWS_PROFILE" ]; then
    PROFILE_FLAG="--profile ${AWS_PROFILE}"
fi

echo "=========================================="
echo "Monitoring Stack: ${STACK_NAME}"
echo "Region: ${AWS_REGION}"
if [ -n "$AWS_PROFILE" ]; then
    echo "AWS Profile: ${AWS_PROFILE}"
fi
echo "=========================================="
echo ""

# Check if stack exists
if ! aws cloudformation describe-stacks \
    --stack-name ${STACK_NAME} \
    --region ${AWS_REGION} \
    ${PROFILE_FLAG} &> /dev/null; then
    echo -e "${RED}✗${NC} Stack not found: ${STACK_NAME}"
    exit 1
fi

# Get initial status
STACK_STATUS=$(aws cloudformation describe-stacks \
    --stack-name ${STACK_NAME} \
    --query 'Stacks[0].StackStatus' \
    --output text \
    --region ${AWS_REGION} \
    ${PROFILE_FLAG})

echo "Current Status: ${STACK_STATUS}"
echo ""

# Monitor until complete
echo "Monitoring stack events (Ctrl+C to stop)..."
echo ""

LAST_EVENT_TIME=""

while true; do
    # Get latest events
    EVENTS=$(aws cloudformation describe-stack-events \
        --stack-name ${STACK_NAME} \
        --region ${AWS_REGION} \
        --query 'StackEvents[*].[Timestamp,ResourceStatus,ResourceType,LogicalResourceId,ResourceStatusReason]' \
        --output text \
        ${PROFILE_FLAG})
    
    # Display new events
    while IFS=$'\t' read -r timestamp status type logical_id reason; do
        if [ -z "$LAST_EVENT_TIME" ] || [[ "$timestamp" > "$LAST_EVENT_TIME" ]]; then
            # Color code based on status
            case $status in
                *COMPLETE)
                    COLOR=$GREEN
                    ;;
                *FAILED|*ROLLBACK*)
                    COLOR=$RED
                    ;;
                *IN_PROGRESS)
                    COLOR=$YELLOW
                    ;;
                *)
                    COLOR=$NC
                    ;;
            esac
            
            echo -e "${COLOR}${timestamp}${NC} ${status} ${type} ${logical_id}"
            if [ -n "$reason" ] && [ "$reason" != "None" ]; then
                echo "  Reason: ${reason}"
            fi
            
            LAST_EVENT_TIME=$timestamp
        fi
    done <<< "$EVENTS"
    
    # Check current status
    CURRENT_STATUS=$(aws cloudformation describe-stacks \
        --stack-name ${STACK_NAME} \
        --query 'Stacks[0].StackStatus' \
        --output text \
        --region ${AWS_REGION} \
        ${PROFILE_FLAG})
    
    # Check if complete
    case $CURRENT_STATUS in
        CREATE_COMPLETE|UPDATE_COMPLETE)
            echo ""
            echo -e "${GREEN}✓${NC} Stack operation completed successfully!"
            echo ""
            
            # Display outputs
            echo "Stack Outputs:"
            aws cloudformation describe-stacks \
                --stack-name ${STACK_NAME} \
                --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue,Description]' \
                --output table \
                --region ${AWS_REGION} \
                ${PROFILE_FLAG}
            
            exit 0
            ;;
        *FAILED|*ROLLBACK_COMPLETE)
            echo ""
            echo -e "${RED}✗${NC} Stack operation failed!"
            echo ""
            echo "Check the events above for error details"
            exit 1
            ;;
    esac
    
    # Wait before next check
    sleep 5
done
