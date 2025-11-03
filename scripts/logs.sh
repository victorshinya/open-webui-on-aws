#!/bin/bash

# View Open WebUI logs

# Follow logs by default, or show last N lines if argument provided
if [ -z "$1" ]; then
    echo "Following Open WebUI logs (Ctrl+C to exit)..."
    echo ""
    if command -v docker-compose &> /dev/null; then
        docker-compose logs -f open-webui
    else
        docker compose logs -f open-webui
    fi
else
    echo "Showing last $1 lines of logs..."
    echo ""
    if command -v docker-compose &> /dev/null; then
        docker-compose logs --tail="$1" open-webui
    else
        docker compose logs --tail="$1" open-webui
    fi
fi
