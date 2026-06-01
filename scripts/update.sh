#!/bin/bash
set -e

echo "Updating Mowbot Stack..."

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
cd "$DIR"

ENV_FILE="mowbot.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE not found. Run scripts/install.sh first."
    exit 1
fi

read -p "Update mowbot.env settings (robot/MQTT options from install)? (y/N): " UPDATE_ENV
if [[ "$UPDATE_ENV" =~ ^[Yy]$ ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$ENV_FILE"
    set +a
    MB_ROBOT_ID="${MB_ROBOT_ID:-mowbot_001}"
    MB_MANUFACTURER="${MB_MANUFACTURER:-MowbotTech}"
    MB_ROBOT_MODEL="${MB_ROBOT_MODEL:-mowbot_model_t2}"
    MB_SENSOR_MODEL="${MB_SENSOR_MODEL:-mowbot_sensor_kit_t2}"
    MB_MQTT_HOST="${MB_MQTT_HOST:-localhost}"
    MB_MQTT_PORT="${MB_MQTT_PORT:-1883}"
    MB_MQTT_USE_TLS="${MB_MQTT_USE_TLS:-false}"
    MB_MQTT_USER="${MB_MQTT_USER:-}"
    MB_MQTT_PASSWORD="${MB_MQTT_PASSWORD:-}"
    MB_DATA_PATH="${MB_DATA_PATH:-}"

    echo "--- Update machine config ($ENV_FILE) ---"
    echo "Press Enter on each prompt to keep the current value."
    read -p "Enter Robot ID (current: $MB_ROBOT_ID): " INPUT_MB_ROBOT_ID
    MB_ROBOT_ID="${INPUT_MB_ROBOT_ID:-$MB_ROBOT_ID}"
    read -p "Enter Robot Model (current: $MB_ROBOT_MODEL): " INPUT_MB_ROBOT_MODEL
    MB_ROBOT_MODEL="${INPUT_MB_ROBOT_MODEL:-$MB_ROBOT_MODEL}"
    read -p "Enter Sensor Model (current: $MB_SENSOR_MODEL): " INPUT_MB_SENSOR_MODEL
    MB_SENSOR_MODEL="${INPUT_MB_SENSOR_MODEL:-$MB_SENSOR_MODEL}"
    read -p "Enter Manufacturer (current: $MB_MANUFACTURER): " INPUT_MB_MANUFACTURER
    MB_MANUFACTURER="${INPUT_MB_MANUFACTURER:-$MB_MANUFACTURER}"
    read -p "Enter MQTT broker host (current: $MB_MQTT_HOST): " INPUT_MB_MQTT_HOST
    MB_MQTT_HOST="${INPUT_MB_MQTT_HOST:-$MB_MQTT_HOST}"
    read -p "Enter MQTT broker port (current: $MB_MQTT_PORT): " INPUT_MB_MQTT_PORT
    MB_MQTT_PORT="${INPUT_MB_MQTT_PORT:-$MB_MQTT_PORT}"
    read -p "Use MQTT TLS? (current: $MB_MQTT_USE_TLS, y/N): " INPUT_MB_MQTT_USE_TLS
    if [ -n "$INPUT_MB_MQTT_USE_TLS" ]; then
        case "${INPUT_MB_MQTT_USE_TLS,,}" in
            y|yes|true|1) MB_MQTT_USE_TLS=true ;;
            *) MB_MQTT_USE_TLS=false ;;
        esac
    fi
    {
        echo "MB_ROBOT_ID=$MB_ROBOT_ID"
        echo "MB_MANUFACTURER=$MB_MANUFACTURER"
        echo "MB_ROBOT_MODEL=$MB_ROBOT_MODEL"
        echo "MB_SENSOR_MODEL=$MB_SENSOR_MODEL"
        echo ""
        echo "MB_MQTT_HOST=$MB_MQTT_HOST"
        echo "MB_MQTT_PORT=$MB_MQTT_PORT"
        echo "MB_MQTT_USE_TLS=$MB_MQTT_USE_TLS"
        echo "MB_MQTT_USER=$MB_MQTT_USER"
        echo "MB_MQTT_PASSWORD=$MB_MQTT_PASSWORD"
        echo ""
        echo "MB_DATA_PATH=$MB_DATA_PATH"
    } > "$ENV_FILE"
    chmod 600 "$ENV_FILE" 2>/dev/null || true
    echo "Saved to $ENV_FILE"
    echo ""
fi

# Docker should already be logged in from install.sh
if [ -n "${SUDO_USER:-}" ] && id -u "$SUDO_USER" >/dev/null 2>&1; then
    COMPOSE_USER="$SUDO_USER"
else
    COMPOSE_USER="$(id -un)"
fi
COMPOSE_HOME="$(getent passwd "$COMPOSE_USER" | cut -d: -f6)"
compose() {
    HOME="$COMPOSE_HOME" docker compose --env-file mowbot.env -f docker-compose.yml "$@"
}

STACK_SERVICES=(
    mowbot_uros_agent
    mowbot_bringup_and_sensing
    mowbot_localization
    mowbot_navigation
    mowbot_app
)

echo "Pulling latest Docker images from ghcr.io..."
compose pull

echo "Recreating stack containers without starting (same as install; start manually when ready)..."
compose up --force-recreate --no-start "${STACK_SERVICES[@]}"

echo "Restarting GUI and WebUI services to apply updates..."
sudo systemctl restart mowbot_gui.service mowbot_config_webui.service

echo "Update complete!"
