#!/bin/bash

# Reset Open WebUI - stops containers and removes data

set -e

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${RED}WARNING: This will delete all Open WebUI data!${NC}"
echo "This includes:"
echo "  - Chat history"
echo "  - User preferences"
echo "  - Downloaded models"
echo "  - Uploaded files"
echo ""
read -p "Are you sure you want to continue? (type 'yes' to confirm) " -r
echo ""

if [[ ! $REPLY == "yes" ]]; then
    echo "Reset cancelled"
    exit 0
fi

echo "Stopping Open WebUI..."
if command -v docker-compose &> /dev/null; then
    docker-compose down
else
    docker compose down
fi

echo "Removing data volume..."
docker volume rm open-webui-data 2>/dev/null || true

echo ""
echo -e "${GREEN}✓${NC} Open WebUI has been reset"
echo ""
echo "Start fresh with: ./scripts/start.sh"
echo ""
