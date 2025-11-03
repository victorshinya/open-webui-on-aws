#!/bin/bash

# Open WebUI Local Setup Script
# This script validates prerequisites and sets up the local development environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Open WebUI Local Setup"
echo "=========================================="
echo ""

# Function to print colored messages
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "ℹ $1"
}

# Check if Docker is installed
check_docker() {
    print_info "Checking Docker installation..."
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        echo "Please install Docker from: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        echo "Please start Docker and try again"
        exit 1
    fi
    
    DOCKER_VERSION=$(docker --version | cut -d ' ' -f3 | cut -d ',' -f1)
    print_success "Docker installed (version $DOCKER_VERSION)"
}

# Check if Docker Compose is installed
check_docker_compose() {
    print_info "Checking Docker Compose installation..."
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed"
        echo "Please install Docker Compose from: https://docs.docker.com/compose/install/"
        exit 1
    fi
    
    if command -v docker-compose &> /dev/null; then
        COMPOSE_VERSION=$(docker-compose --version | cut -d ' ' -f4 | cut -d ',' -f1)
    else
        COMPOSE_VERSION=$(docker compose version --short)
    fi
    print_success "Docker Compose installed (version $COMPOSE_VERSION)"
}

# Check if .env.local exists
check_env_file() {
    print_info "Checking environment configuration..."
    if [ ! -f ".env.local" ]; then
        print_warning ".env.local file not found"
        echo ""
        read -p "Would you like to create .env.local from .env.example? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cp .env.example .env.local
            print_success "Created .env.local from template"
            print_warning "Please edit .env.local with your Cognito configuration before starting"
            echo ""
            echo "Required variables to configure:"
            echo "  - COGNITO_USER_POOL_ID"
            echo "  - OAUTH_CLIENT_ID"
            echo "  - OAUTH_CLIENT_SECRET"
            echo "  - AWS_REGION"
            echo "  - COGNITO_DOMAIN"
            echo "  - WEBUI_SECRET_KEY (generate with: openssl rand -hex 32)"
            echo ""
            exit 0
        else
            print_error "Cannot proceed without .env.local file"
            exit 1
        fi
    else
        print_success ".env.local file exists"
    fi
}

# Validate required environment variables
validate_env_vars() {
    print_info "Validating environment variables..."
    
    # Source the .env.local file
    set -a
    source .env.local
    set +a
    
    MISSING_VARS=()
    
    # Check required variables
    [ -z "$OAUTH_CLIENT_ID" ] && MISSING_VARS+=("OAUTH_CLIENT_ID")
    [ -z "$OAUTH_CLIENT_SECRET" ] && MISSING_VARS+=("OAUTH_CLIENT_SECRET")
    [ -z "$COGNITO_USER_POOL_ID" ] && MISSING_VARS+=("COGNITO_USER_POOL_ID")
    [ -z "$AWS_REGION" ] && MISSING_VARS+=("AWS_REGION")
    [ -z "$WEBUI_SECRET_KEY" ] && MISSING_VARS+=("WEBUI_SECRET_KEY")
    
    if [ ${#MISSING_VARS[@]} -gt 0 ]; then
        print_error "Missing required environment variables:"
        for var in "${MISSING_VARS[@]}"; do
            echo "  - $var"
        done
        echo ""
        echo "Please edit .env.local and add the missing values"
        exit 1
    fi
    
    print_success "All required environment variables are set"
}

# Check if port is available
check_port() {
    print_info "Checking if port ${PORT:-3000} is available..."
    
    if lsof -Pi :${PORT:-3000} -sTCP:LISTEN -t >/dev/null 2>&1 ; then
        print_warning "Port ${PORT:-3000} is already in use"
        echo "Please stop the service using this port or change PORT in .env.local"
        exit 1
    fi
    
    print_success "Port ${PORT:-3000} is available"
}

# Main execution
main() {
    check_docker
    check_docker_compose
    check_env_file
    validate_env_vars
    check_port
    
    echo ""
    echo "=========================================="
    print_success "Setup validation complete!"
    echo "=========================================="
    echo ""
    echo "You can now start Open WebUI with:"
    echo "  docker-compose up -d"
    echo ""
    echo "Or use the helper scripts:"
    echo "  ./scripts/start.sh    - Start Open WebUI"
    echo "  ./scripts/stop.sh     - Stop Open WebUI"
    echo "  ./scripts/logs.sh     - View logs"
    echo "  ./scripts/reset.sh    - Reset and clean data"
    echo ""
}

main
