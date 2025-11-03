#!/bin/bash

# Validate CloudFormation templates

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "CloudFormation Template Validation"
echo "=========================================="
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}✗${NC} AWS CLI is not installed"
    echo "Install from: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Check if cfn-lint is installed (optional but recommended)
if command -v cfn-lint &> /dev/null; then
    USE_CFN_LINT=true
    echo -e "${GREEN}✓${NC} cfn-lint found, will use for enhanced validation"
else
    USE_CFN_LINT=false
    echo -e "${YELLOW}⚠${NC} cfn-lint not found (optional), install with: pip install cfn-lint"
fi

echo ""

# Get AWS region
AWS_REGION=${AWS_REGION:-us-east-1}
echo "Using AWS Region: ${AWS_REGION}"
echo ""

# Templates to validate
TEMPLATES=(
    "cloudformation/network.yaml"
    "cloudformation/security-groups.yaml"
    "cloudformation/cognito.yaml"
    "cloudformation/storage.yaml"
    "cloudformation/compute.yaml"
    "cloudformation/loadbalancer.yaml"
    "cloudformation/monitoring.yaml"
    "cloudformation/main-stack.yaml"
)

FAILED=0
PASSED=0

for template in "${TEMPLATES[@]}"; do
    echo "Validating: ${template}"
    
    # AWS CloudFormation validation
    if aws cloudformation validate-template \
        --template-body file://${template} \
        --region ${AWS_REGION} \
        --output json > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} AWS validation passed"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} AWS validation failed"
        aws cloudformation validate-template \
            --template-body file://${template} \
            --region ${AWS_REGION} 2>&1 | grep -i error || true
        ((FAILED++))
    fi
    
    # cfn-lint validation (if available)
    if [ "$USE_CFN_LINT" = true ]; then
        if cfn-lint ${template} --region ${AWS_REGION}; then
            echo -e "${GREEN}✓${NC} cfn-lint validation passed"
        else
            echo -e "${YELLOW}⚠${NC} cfn-lint found issues (warnings may be acceptable)"
        fi
    fi
    
    echo ""
done

echo "=========================================="
echo "Validation Summary"
echo "=========================================="
echo -e "Passed: ${GREEN}${PASSED}${NC}"
echo -e "Failed: ${RED}${FAILED}${NC}"
echo ""

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}✗${NC} Validation failed for ${FAILED} template(s)"
    exit 1
else
    echo -e "${GREEN}✓${NC} All templates validated successfully!"
    exit 0
fi
