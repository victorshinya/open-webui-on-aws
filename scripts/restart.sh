#!/bin/bash

# Restart Open WebUI

set -e

GREEN='\033[0;32m'
NC='\033[0m'

echo "Restarting Open WebUI..."

if command -v docker-compose &> /dev/null; then
    docker-compose restart open-webui
else
    docker compose restart open-webui
fi

echo ""
echo -e "${GREEN}✓${NC} Open WebUI restarted"
echo ""
echo "View logs with: ./scripts/logs.sh"
echo ""
