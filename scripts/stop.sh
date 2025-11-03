#!/bin/bash

# Stop Open WebUI

set -e

GREEN='\033[0;32m'
NC='\033[0m'

echo "Stopping Open WebUI..."

if command -v docker-compose &> /dev/null; then
    docker-compose down
else
    docker compose down
fi

echo ""
echo -e "${GREEN}✓${NC} Open WebUI stopped"
echo ""
