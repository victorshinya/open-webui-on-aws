#!/bin/bash

# Test deployed Open WebUI infrastructure

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
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
echo "Testing Open WebUI Deployment"
echo "=========================================="
echo ""
echo "Stack Name: ${STACK_NAME}"
echo "Region:     ${AWS_REGION}"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

# Helper function to run tests
run_test() {
    local test_name=$1
    local test_command=$2
    
    echo -n "Testing ${test_name}... "
    
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test 1: Stack exists and is in good state
echo -e "${BLUE}1. Stack Status${NC}"
STACK_STATUS=$(aws cloudformation describe-stacks \
    --stack-name ${STACK_NAME} \
    --query 'Stacks[0].StackStatus' \
    --output text \
    --region ${AWS_REGION} 2>/dev/null || echo "NOT_FOUND")

if [[ "$STACK_STATUS" == "CREATE_COMPLETE" || "$STACK_STATUS" == "UPDATE_COMPLETE" ]]; then
    echo -e "   ${GREEN}✓${NC} Stack status: ${STACK_STATUS}"
    ((TESTS_PASSED++))
else
    echo -e "   ${RED}✗${NC} Stack status: ${STACK_STATUS}"
    ((TESTS_FAILED++))
fi
echo ""

# Get stack outputs
ALB_DNS=$(aws cloudformation describe-stacks \
    --stack-name ${STACK_NAME} \
    --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNSName`].OutputValue' \
    --output text \
    --region ${AWS_REGION} 2>/dev/null || echo "")

WEBUI_URL=$(aws cloudformation describe-stacks \
    --stack-name ${STACK_NAME} \
    --query 'Stacks[0].Outputs[?OutputKey==`OpenWebUIURL`].OutputValue' \
    --output text \
    --region ${AWS_REGION} 2>/dev/null || echo "")

ECS_CLUSTER=$(aws cloudformation describe-stacks \
    --stack-name ${STACK_NAME} \
    --query 'Stacks[0].Outputs[?OutputKey==`ECSClusterName`].OutputValue' \
    --output text \
    --region ${AWS_REGION} 2>/dev/null || echo "")

ECS_SERVICE=$(aws cloudformation describe-stacks \
    --stack-name ${STACK_NAME} \
    --query 'Stacks[0].Outputs[?OutputKey==`ECSService`].OutputValue' \
    --output text \
    --region ${AWS_REGION} 2>/dev/null || echo "")

EFS_ID=$(aws cloudformation describe-stacks \
    --stack-name ${STACK_NAME} \
    --query 'Stacks[0].Outputs[?OutputKey==`EFSFileSystemId`].OutputValue' \
    --output text \
    --region ${AWS_REGION} 2>/dev/null || echo "")

# Test 2: ALB Health
echo -e "${BLUE}2. Application Load Balancer${NC}"
if [ -n "$ALB_DNS" ]; then
    run_test "ALB DNS resolution" "nslookup ${ALB_DNS}"
    run_test "ALB HTTPS endpoint" "curl -k -s -o /dev/null -w '%{http_code}' https://${ALB_DNS} | grep -E '200|301|302'"
else
    echo -e "   ${RED}✗${NC} ALB DNS not found"
    ((TESTS_FAILED++))
fi
echo ""

# Test 3: ECS Service Health
echo -e "${BLUE}3. ECS Service${NC}"
if [ -n "$ECS_CLUSTER" ] && [ -n "$ECS_SERVICE" ]; then
    RUNNING_COUNT=$(aws ecs describe-services \
        --cluster ${ECS_CLUSTER} \
        --services ${ECS_SERVICE} \
        --query 'services[0].runningCount' \
        --output text \
        --region ${AWS_REGION} 2>/dev/null || echo "0")
    
    DESIRED_COUNT=$(aws ecs describe-services \
        --cluster ${ECS_CLUSTER} \
        --services ${ECS_SERVICE} \
        --query 'services[0].desiredCount' \
        --output text \
        --region ${AWS_REGION} 2>/dev/null || echo "0")
    
    if [ "$RUNNING_COUNT" -eq "$DESIRED_COUNT" ] && [ "$RUNNING_COUNT" -gt 0 ]; then
        echo -e "   ${GREEN}✓${NC} Running tasks: ${RUNNING_COUNT}/${DESIRED_COUNT}"
        ((TESTS_PASSED++))
    else
        echo -e "   ${RED}✗${NC} Running tasks: ${RUNNING_COUNT}/${DESIRED_COUNT}"
        ((TESTS_FAILED++))
    fi
    
    # Check task health
    TASK_ARNS=$(aws ecs list-tasks \
        --cluster ${ECS_CLUSTER} \
        --service-name ${ECS_SERVICE} \
        --query 'taskArns[0]' \
        --output text \
        --region ${AWS_REGION} 2>/dev/null || echo "")
    
    if [ -n "$TASK_ARNS" ] && [ "$TASK_ARNS" != "None" ]; then
        TASK_STATUS=$(aws ecs describe-tasks \
            --cluster ${ECS_CLUSTER} \
            --tasks ${TASK_ARNS} \
            --query 'tasks[0].lastStatus' \
            --output text \
            --region ${AWS_REGION} 2>/dev/null || echo "UNKNOWN")
        
        if [ "$TASK_STATUS" == "RUNNING" ]; then
            echo -e "   ${GREEN}✓${NC} Task status: ${TASK_STATUS}"
            ((TESTS_PASSED++))
        else
            echo -e "   ${RED}✗${NC} Task status: ${TASK_STATUS}"
            ((TESTS_FAILED++))
        fi
    fi
else
    echo -e "   ${RED}✗${NC} ECS cluster or service not found"
    ((TESTS_FAILED++))
fi
echo ""

# Test 4: EFS Mount
echo -e "${BLUE}4. EFS File System${NC}"
if [ -n "$EFS_ID" ]; then
    EFS_STATE=$(aws efs describe-file-systems \
        --file-system-id ${EFS_ID} \
        --query 'FileSystems[0].LifeCycleState' \
        --output text \
        --region ${AWS_REGION} 2>/dev/null || echo "UNKNOWN")
    
    if [ "$EFS_STATE" == "available" ]; then
        echo -e "   ${GREEN}✓${NC} EFS state: ${EFS_STATE}"
        ((TESTS_PASSED++))
    else
        echo -e "   ${RED}✗${NC} EFS state: ${EFS_STATE}"
        ((TESTS_FAILED++))
    fi
    
    # Check mount targets
    MOUNT_COUNT=$(aws efs describe-mount-targets \
        --file-system-id ${EFS_ID} \
        --query 'length(MountTargets)' \
        --output text \
        --region ${AWS_REGION} 2>/dev/null || echo "0")
    
    if [ "$MOUNT_COUNT" -ge 2 ]; then
        echo -e "   ${GREEN}✓${NC} Mount targets: ${MOUNT_COUNT}"
        ((TESTS_PASSED++))
    else
        echo -e "   ${YELLOW}⚠${NC} Mount targets: ${MOUNT_COUNT} (expected 2+)"
        ((TESTS_FAILED++))
    fi
else
    echo -e "   ${RED}✗${NC} EFS ID not found"
    ((TESTS_FAILED++))
fi
echo ""

# Test 5: CloudWatch Logs
echo -e "${BLUE}5. CloudWatch Logging${NC}"
LOG_GROUP="/ecs/${STACK_NAME}/open-webui"
if aws logs describe-log-groups \
    --log-group-name-prefix ${LOG_GROUP} \
    --region ${AWS_REGION} 2>/dev/null | grep -q ${LOG_GROUP}; then
    echo -e "   ${GREEN}✓${NC} Log group exists"
    ((TESTS_PASSED++))
    
    # Check for recent log streams
    RECENT_LOGS=$(aws logs describe-log-streams \
        --log-group-name ${LOG_GROUP} \
        --order-by LastEventTime \
        --descending \
        --max-items 1 \
        --query 'logStreams[0].lastEventTimestamp' \
        --output text \
        --region ${AWS_REGION} 2>/dev/null || echo "0")
    
    if [ "$RECENT_LOGS" != "0" ] && [ "$RECENT_LOGS" != "None" ]; then
        CURRENT_TIME=$(date +%s)000
        TIME_DIFF=$(( (CURRENT_TIME - RECENT_LOGS) / 1000 / 60 ))
        
        if [ $TIME_DIFF -lt 10 ]; then
            echo -e "   ${GREEN}✓${NC} Recent logs found (${TIME_DIFF} minutes ago)"
            ((TESTS_PASSED++))
        else
            echo -e "   ${YELLOW}⚠${NC} Last log ${TIME_DIFF} minutes ago"
        fi
    fi
else
    echo -e "   ${RED}✗${NC} Log group not found"
    ((TESTS_FAILED++))
fi
echo ""

# Test 6: Cognito Authentication
echo -e "${BLUE}6. Cognito Configuration${NC}"
USER_POOL_ID=$(aws cloudformation describe-stacks \
    --stack-name ${STACK_NAME} \
    --query 'Stacks[0].Outputs[?OutputKey==`CognitoUserPoolId`].OutputValue' \
    --output text \
    --region ${AWS_REGION} 2>/dev/null || echo "")

if [ -n "$USER_POOL_ID" ]; then
    POOL_STATUS=$(aws cognito-idp describe-user-pool \
        --user-pool-id ${USER_POOL_ID} \
        --query 'UserPool.Status' \
        --output text \
        --region ${AWS_REGION} 2>/dev/null || echo "UNKNOWN")
    
    if [ "$POOL_STATUS" == "Enabled" ]; then
        echo -e "   ${GREEN}✓${NC} User pool status: ${POOL_STATUS}"
        ((TESTS_PASSED++))
    else
        echo -e "   ${RED}✗${NC} User pool status: ${POOL_STATUS}"
        ((TESTS_FAILED++))
    fi
else
    echo -e "   ${RED}✗${NC} User pool ID not found"
    ((TESTS_FAILED++))
fi
echo ""

# Summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Failed: ${RED}${TESTS_FAILED}${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
    echo "Access Open WebUI at:"
    echo "  ${WEBUI_URL}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  - Check CloudWatch logs: ./scripts/view-logs.sh ${STACK_NAME}"
    echo "  - View stack events: ./scripts/view-stack-events.sh ${STACK_NAME}"
    echo "  - Check ECS service: aws ecs describe-services --cluster ${ECS_CLUSTER} --services ${ECS_SERVICE}"
    exit 1
fi
