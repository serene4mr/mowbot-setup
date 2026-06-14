#!/bin/bash
set -e

# Keep existing env variable if set, otherwise default to empty
RESET_MOWBOT_DATA="${RESET_MOWBOT_DATA:-}"

# Parse command line options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -r|--reset-data) RESET_MOWBOT_DATA=true; shift ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -r, --reset-data   Reset mowbot_data by removing the existing directory and cloning fresh."
            echo "  -h, --help         Show this help message."
            exit 0
            ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
done

echo "Updating Mowbot Stack..."

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
cd "$DIR"

if [ -n "${SUDO_USER:-}" ] && id -u "$SUDO_USER" >/dev/null 2>&1; then
    COMPOSE_USER="$SUDO_USER"
else
    COMPOSE_USER="$(id -un)"
fi
COMPOSE_GROUP="$(id -gn "$COMPOSE_USER")"
COMPOSE_HOME="$(getent passwd "$COMPOSE_USER" | cut -d: -f6)"

ENV_FILE="/etc/mowbot.env"
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
    TMP_ENV="$(mktemp)"
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
    } > "$TMP_ENV"
    sudo install -m 600 -o "$COMPOSE_USER" -g "$COMPOSE_GROUP" "$TMP_ENV" "$ENV_FILE"
    rm -f "$TMP_ENV"
    echo "Saved to $ENV_FILE"
    echo ""
fi

# Update/reset mowbot_data repository
DATA_HOST_DIR="/etc/mowbot_data"
DATA_REPO_URL="https://github.com/serene4mr/mowbot_data"

echo "Ensuring host data directory exists at $DATA_HOST_DIR ..."
if [ -d "$DATA_HOST_DIR" ]; then
    if [ -z "$RESET_MOWBOT_DATA" ]; then
        if [ -t 0 ]; then
            read -p "Found existing mowbot_data at $DATA_HOST_DIR. Reset to default (discard all local changes/files)? y/N (default: N): " INPUT_RESET_MOWBOT_DATA || INPUT_RESET_MOWBOT_DATA="n"
        else
            INPUT_RESET_MOWBOT_DATA="n"
        fi
    else
        INPUT_RESET_MOWBOT_DATA="$RESET_MOWBOT_DATA"
    fi

    case "${INPUT_RESET_MOWBOT_DATA,,}" in
        y|yes|true|1)
            echo "Resetting mowbot_data by removing existing directory and cloning fresh..."
            sudo rm -rf "$DATA_HOST_DIR"
            echo "Cloning mowbot_data to $DATA_HOST_DIR ..."
            sudo git clone "$DATA_REPO_URL" "$DATA_HOST_DIR"
            ;;
        *)
            if [ -d "$DATA_HOST_DIR/.git" ]; then
                echo "Updating mowbot_data at $DATA_HOST_DIR ..."
                set +e
                sudo -u "$COMPOSE_USER" git -C "$DATA_HOST_DIR" pull --ff-only
                GIT_PULL_STATUS=$?
                set -e
                if [ $GIT_PULL_STATUS -ne 0 ]; then
                    echo "Warning: git pull failed (possibly due to local modifications)."
                    echo "Keeping current local mowbot_data files."
                fi
            else
                echo "Keeping existing non-git directory at $DATA_HOST_DIR."
            fi
            ;;
    esac
else
    echo "Cloning mowbot_data to $DATA_HOST_DIR ..."
    sudo git clone "$DATA_REPO_URL" "$DATA_HOST_DIR"
fi
sudo chown -R "$COMPOSE_USER:$COMPOSE_GROUP" "$DATA_HOST_DIR"
echo ""

# Docker should already be logged in from install.sh
compose() {
    HOME="$COMPOSE_HOME" docker compose --env-file /etc/mowbot.env -f docker-compose.yml "$@"
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

echo "Restarting GUI, WebUI, and MapProxy services to apply updates..."
sudo systemctl restart mowbot_gui.service mowbot_utility_webui.service mowbot_mapproxy.service

echo "Update complete!"
