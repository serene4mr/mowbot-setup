#!/bin/bash
set -e

echo "Updating Mowbot Stack..."

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
cd "$DIR"

# Docker should already be logged in perfectly from install.sh
echo "Pulling latest Docker images from ghcr.io..."
docker compose --env-file mowbot.env pull

echo "Restarting service to apply updates..."
sudo systemctl restart mowbot_gui.service

echo "Update complete!"
