#!/bin/bash
set -e

echo "Uninstalling Mowbot Stack..."

# 1. Stop and disable systemd service
if systemctl is-active --quiet mowbot.service; then
    echo "Stopping mowbot.service..."
    sudo systemctl stop mowbot.service
fi

if systemctl is-enabled --quiet mowbot.service; then
    echo "Disabling mowbot.service..."
    sudo systemctl disable mowbot.service
fi

sudo rm -f /etc/systemd/system/mowbot.service
sudo systemctl daemon-reload

# 2. Stop Docker containers
echo "Stopping Docker containers..."
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
cd "$DIR"
docker compose down || true

# 3. Optional: Uninstall Mosquitto
read -p "Do you want to uninstall Mosquitto MQTT from the host? (y/N): " UNINSTALL_MQTT
if [[ "$UNINSTALL_MQTT" =~ ^[Yy]$ ]]; then
    echo "Uninstalling Mosquitto..."
    sudo apt-get purge -y mosquitto mosquitto-clients
    sudo apt-get autoremove -y
    sudo rm -f /etc/mosquitto/conf.d/mowbot.conf
fi

echo "Mowbot uninstalled successfully."
