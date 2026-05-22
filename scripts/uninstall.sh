#!/bin/bash
set -e

echo "Uninstalling Mowbot Stack..."

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
cd "$DIR"

if [ -n "${SUDO_USER:-}" ] && id -u "$SUDO_USER" >/dev/null 2>&1; then
    COMPOSE_USER="$SUDO_USER"
else
    COMPOSE_USER="$(id -un)"
fi
COMPOSE_HOME="$(getent passwd "$COMPOSE_USER" | cut -d: -f6)"
compose() {
    HOME="$COMPOSE_HOME" docker compose --env-file mowbot.env -f docker-compose.yml "$@"
}

# 1. Stop and disable systemd service
if sudo systemctl is-active --quiet mowbot_gui.service; then
    echo "Stopping mowbot_gui.service..."
    sudo systemctl stop mowbot_gui.service
fi

if sudo systemctl is-enabled --quiet mowbot_gui.service; then
    echo "Disabling mowbot_gui.service..."
    sudo systemctl disable mowbot_gui.service
fi

sudo rm -f /etc/systemd/system/mowbot_gui.service
sudo systemctl daemon-reload

# Runtime env written by mowbot_gui.service ExecStartPre
sudo rm -f /tmp/mowbot-xauth.env

# 2. Stop Docker containers (needs mowbot.env while compose runs)
echo "Stopping Docker containers..."
if [ -f mowbot.env ]; then
    compose down || true
else
    echo "No mowbot.env found; skipping compose down."
fi

# 3. Optional: remove machine config created by install.sh
read -p "Remove mowbot.env (robot/MQTT settings from install)? (y/N): " REMOVE_ENV
if [[ "$REMOVE_ENV" =~ ^[Yy]$ ]]; then
    rm -f mowbot.env .env
    echo "Removed mowbot.env and .env (if present)."
fi

# 4. Optional: Uninstall Mosquitto
read -p "Do you want to uninstall Mosquitto MQTT from the host? (y/N): " UNINSTALL_MQTT
if [[ "$UNINSTALL_MQTT" =~ ^[Yy]$ ]]; then
    echo "Uninstalling Mosquitto..."
    sudo apt-get purge -y mosquitto mosquitto-clients
    sudo apt-get autoremove -y
    sudo rm -f /etc/mosquitto/conf.d/mowbot.conf /etc/mosquitto/conf.d/hivemq-bridge.conf
fi

echo "Mowbot uninstalled successfully."
