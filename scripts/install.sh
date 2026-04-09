#!/bin/bash
set -e

echo "Starting Mowbot Setup..."

# Ensure we are in the correct directory (the project root, one level up from this script)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
cd "$DIR"

# 1. Credentials
if [ -z "$GHCR_USERNAME" ] || [ -z "$GHCR_PAT" ]; then
    echo "This script requires a GitHub Username and Read-Only PAT."
    echo "To automate this, run from the repo root: GHCR_USERNAME=user GHCR_PAT=token ./scripts/install.sh"
    echo ""
    read -p "Enter GitHub Username: " GHCR_USERNAME
    read -sp "Enter GitHub PAT (read:packages): " GHCR_PAT
    echo ""
fi

# 2. Prerequisites
if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is not installed. Install Docker Engine first, then re-run this script."
    exit 1
fi
if ! docker info >/dev/null 2>&1; then
    echo "Docker daemon is not running or this user cannot access it (try 'docker info', or add the user to the 'docker' group)."
    exit 1
fi

echo "Installing Mosquitto MQTT..."
sudo apt-get update && sudo apt-get install -y mosquitto mosquitto-clients

echo "Configuring Mosquitto..."
# Allow anonymous access and set a global listener for version 2.0+
sudo bash -c 'cat > /etc/mosquitto/conf.d/mowbot.conf <<EOF
listener 1883
allow_anonymous true
EOF'

sudo systemctl enable mosquitto
sudo systemctl restart mosquitto

# 3. Machine config: mowbot.env (same file as mowbot.service --env-file and mowbot.env.example)
ENV_FILE="mowbot.env"
if [ -f "$ENV_FILE" ]; then
    echo "Found existing $ENV_FILE, skipping hardware provisioning."
elif [ -f ".env" ]; then
    echo "Migrating .env -> $ENV_FILE (systemd uses $ENV_FILE)."
    cp .env "$ENV_FILE"
    echo "You may delete .env if everything looks correct."
    echo ""
else
    echo "--- Hardware provisioning ($ENV_FILE) ---"
    echo "Copy mowbot.env.example to $ENV_FILE and edit, or answer the prompts below."
    read -p "Enter Robot ID (default: mowbot_001): " INPUT_MB_ROBOT_ID
    read -p "Enter Robot Model (default: mowbot_model_t2): " INPUT_MB_ROBOT_MODEL
    read -p "Enter Sensor Model (default: mowbot_sensor_kit_t2): " INPUT_MB_SENSOR_MODEL
    read -p "Enter Manufacturer (default: MowbotTech): " INPUT_MB_MANUFACTURER
    read -p "Enter MQTT broker host (default: localhost): " INPUT_MB_MQTT_HOST
    read -p "Enter MQTT broker port (default: 1883): " INPUT_MB_MQTT_PORT
    read -p "Use MQTT TLS? y/N (default: N): " INPUT_MB_MQTT_USE_TLS
    case "${INPUT_MB_MQTT_USE_TLS,,}" in
        y|yes|true|1) MB_MQTT_USE_TLS_VALUE=true ;;
        *) MB_MQTT_USE_TLS_VALUE=false ;;
    esac
    {
        echo "MB_ROBOT_ID=${INPUT_MB_ROBOT_ID:-mowbot_001}"
        echo "MB_MANUFACTURER=${INPUT_MB_MANUFACTURER:-MowbotTech}"
        echo "MB_ROBOT_MODEL=${INPUT_MB_ROBOT_MODEL:-mowbot_model_t2}"
        echo "MB_SENSOR_MODEL=${INPUT_MB_SENSOR_MODEL:-mowbot_sensor_kit_t2}"
        echo ""
        echo "MB_MQTT_HOST=${INPUT_MB_MQTT_HOST:-localhost}"
        echo "MB_MQTT_PORT=${INPUT_MB_MQTT_PORT:-1883}"
        echo "MB_MQTT_USE_TLS=$MB_MQTT_USE_TLS_VALUE"
        echo ""
        echo "MB_DATA_PATH="
    } > "$ENV_FILE"
    chmod 600 "$ENV_FILE" 2>/dev/null || true
    echo "Saved to $ENV_FILE"
    echo ""
fi

# 4. Docker Login
echo "Logging into ghcr.io..."
echo "$GHCR_PAT" | docker login ghcr.io -u "$GHCR_USERNAME" --password-stdin

# 5. Pull latest images (same env file as systemd / manual: docker compose --env-file mowbot.env)
echo "Pulling latest Docker images..."
docker compose --env-file mowbot.env pull

# 6. Setup systemd service
SERVICE_FILE="/etc/systemd/system/mowbot.service"

echo "Configuring systemd service in $SERVICE_FILE..."
# Service user: the account that should own compose (invoking user, or SUDO_USER when using sudo).
if [ -n "${SUDO_USER:-}" ] && id -u "$SUDO_USER" >/dev/null 2>&1; then
    SVC_USER="$SUDO_USER"
    SVC_GROUP="$(id -gn "$SUDO_USER")"
else
    SVC_USER="$(id -un)"
    SVC_GROUP="$(id -gn)"
fi
if [ "$SVC_USER" = "root" ]; then
    echo "Warning: systemd User=root. Prefer running install as a normal user (use sudo only for apt/systemctl steps), or edit $SERVICE_FILE."
fi
# Point WorkingDirectory at this clone; escape & for sed replacement
DIR_ESC="${DIR//&/\\&}"
sed -e "s|^User=.*|User=$SVC_USER|" \
    -e "s|^Group=.*|Group=$SVC_GROUP|" \
    -e "s|WorkingDirectory=.*|WorkingDirectory=$DIR_ESC|" \
    "$DIR/mowbot.service" | sudo tee "$SERVICE_FILE" > /dev/null

# 7. Enable and start service
echo "Enabling and starting Mowbot service..."
sudo systemctl daemon-reload
sudo systemctl enable mowbot.service
sudo systemctl restart mowbot.service

echo "Mowbot installation complete! You can view live system status using:"
echo "sudo systemctl status mowbot.service"
