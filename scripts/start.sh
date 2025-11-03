#!/bin/bash

# Start Open WebUI locally

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Starting Open WebUI..."

# Check if .env.local exists
if [ ! -f ".env.local" ]; then
    echo -e "${YELLOW}⚠${NC} .env.local not found. Run ./scripts/local-setup.sh first"
    exit 1
fi

# Start with docker-compose
if command -v docker-compose &> /dev/null; then
    docker-compose --env-file .env.local up -d
else
    docker compose --env-file .env.local up -d
fi

echo ""
echo -e "${GREEN}✓${NC} Open WebUI started successfully!"
echo ""
echo "Access Open WebUI at: http://localhost:${PORT:-3000}"
echo ""
echo "Useful commands:"
echo "  ./scripts/logs.sh     - View logs"
echo "  ./scripts/stop.sh     - Stop Open WebUI"
echo "  ./scripts/restart.sh  - Restart Open WebUI"
echo ""
