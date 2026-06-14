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
    HOME="$COMPOSE_HOME" docker compose --env-file /etc/mowbot.env -f docker-compose.yml "$@"
}

# 1. Stop, disable and remove all systemd services starting with mowbot_
SERVICES=$(find /etc/systemd/system/ -name "mowbot_*.service" -printf "%f\n" 2>/dev/null || true)

if [ -n "$SERVICES" ]; then
    for svc in $SERVICES; do
        if sudo systemctl is-active --quiet "$svc"; then
            echo "Stopping $svc..."
            sudo systemctl stop "$svc"
        fi
        if sudo systemctl is-enabled --quiet "$svc"; then
            echo "Disabling $svc..."
            sudo systemctl disable "$svc"
        fi
        echo "Removing service file for $svc..."
        sudo rm -f "/etc/systemd/system/$svc"
    done
    sudo systemctl daemon-reload
fi

# Runtime env written by mowbot_gui.service ExecStartPre
sudo rm -f /tmp/mowbot-xauth.env

# 2. Stop and remove Docker containers
echo "Stopping and removing Mowbot Docker containers..."
if [ -f /etc/mowbot.env ]; then
    compose down || true
else
    echo "No /etc/mowbot.env found; skipping compose down. Will clean up containers by name filter."
fi

# Force stop and remove any remaining containers starting with mowbot_
REMAINING_CONTAINERS=$(docker ps -a --filter "name=^/mowbot_" -q)
if [ -n "$REMAINING_CONTAINERS" ]; then
    echo "Force removing remaining Mowbot containers..."
    docker rm -f $REMAINING_CONTAINERS || true
fi

# Optionally remove images
read -p "Do you want to remove all Docker images used by Mowbot? (y/N): " REMOVE_IMAGES
if [[ "$REMOVE_IMAGES" =~ ^[Yy]$ ]]; then
    echo "Force removing Docker images..."
    IMAGES=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "mowbot|mapproxy|micro-ros-agent" || true)
    if [ -n "$IMAGES" ]; then
        docker rmi -f $IMAGES || true
    fi
fi

# 3. Optional: remove machine config created by install.sh
read -p "Remove /etc/mowbot.env (robot/MQTT settings from install)? (y/N): " REMOVE_ENV
if [[ "$REMOVE_ENV" =~ ^[Yy]$ ]]; then
    sudo rm -f /etc/mowbot.env
    rm -f mowbot.env .env
    echo "Removed /etc/mowbot.env, mowbot.env and .env (if present)."
fi

# 4. Optional: Uninstall Mosquitto
read -p "Do you want to uninstall Mosquitto MQTT from the host? (y/N): " UNINSTALL_MQTT
if [[ "$UNINSTALL_MQTT" =~ ^[Yy]$ ]]; then
    echo "Uninstalling Mosquitto..."
    sudo apt-get purge -y mosquitto mosquitto-clients
    sudo apt-get autoremove -y
    sudo rm -f /etc/mosquitto/conf.d/mowbot.conf /etc/mosquitto/conf.d/hivemq-bridge.conf
fi

# 5. Optional: Remove mowbot_data directory
DATA_HOST_DIR="/etc/mowbot_data"
if [ -d "$DATA_HOST_DIR" ]; then
    read -p "Do you want to remove the mowbot_data directory ($DATA_HOST_DIR) and all its contents? (y/N): " REMOVE_DATA
    if [[ "$REMOVE_DATA" =~ ^[Yy]$ ]]; then
        echo "Removing $DATA_HOST_DIR..."
        sudo rm -rf "$DATA_HOST_DIR"
    fi
fi

echo "Mowbot uninstalled successfully."
