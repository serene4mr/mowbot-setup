#!/bin/bash
set -e

echo "Starting Mowbot Setup..."

# Ensure we are in the correct directory (the project root, one level up from this script)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
cd "$DIR"

# 1. Credentials
if [ -z "$GHCR_USERNAME" ] || [ -z "$GHCR_PAT" ]; then
    echo "This script requires a GitHub Username and Read-Only PAT."
    echo "To automate this, run: GHCR_USERNAME=user GHCR_PAT=token ./install.sh"
    echo ""
    read -p "Enter GitHub Username: " GHCR_USERNAME
    read -sp "Enter GitHub PAT (read:packages): " GHCR_PAT
    echo ""
fi

# 2. Prerequisites
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

# 3. Hardware Provisioning (Creates .env for Docker Compose)
if [ ! -f ".env" ]; then
    echo "--- Hardware Provisioning ---"
    echo "Found no .env file, prompting for robot specifics..."
    read -p "Enter Robot ID (default: mowbot_001): " INPUT_MB_ROBOT_ID
    read -p "Enter Robot Model (default: mowbot_model_t2): " INPUT_MB_ROBOT_MODEL
    read -p "Enter Sensor Model (default: mowbot_sensor_kit_t2): " INPUT_MB_SENSOR_MODEL
    read -p "Enter Manufacturer (default: unknown): " INPUT_MB_MANUFACTURER
    
    echo "MB_ROBOT_ID=${INPUT_MB_ROBOT_ID:-mowbot_001}" > .env
    echo "MB_ROBOT_MODEL=${INPUT_MB_ROBOT_MODEL:-mowbot_model_t2}" >> .env
    echo "MB_SENSOR_MODEL=${INPUT_MB_SENSOR_MODEL:-mowbot_sensor_kit_t2}" >> .env
    echo "MB_MANUFACTURER=${INPUT_MB_MANUFACTURER:-unknown}" >> .env
    echo "Saved to .env!"
    echo ""
else
    echo "Found existing .env file, skipping hardware provisioning."
fi

# 4. Docker Login
echo "Logging into ghcr.io..."
echo "$GHCR_PAT" | docker login ghcr.io -u "$GHCR_USERNAME" --password-stdin

# 5. Pull latest images
echo "Pulling latest Docker images..."
docker compose pull

# 6. Setup systemd service
SERVICE_FILE="/etc/systemd/system/mowbot.service"

echo "Configuring systemd service in $SERVICE_FILE..."
# Dynamically adjust WorkingDirectory and install the file safely without changing git files
sed "s|WorkingDirectory=.*|WorkingDirectory=$DIR|g" "$DIR/mowbot.service" | sudo tee "$SERVICE_FILE" > /dev/null

# 7. Enable and start service
echo "Enabling and starting Mowbot service..."
sudo systemctl daemon-reload
sudo systemctl enable mowbot.service
sudo systemctl restart mowbot.service

echo "Mowbot installation complete! You can view live system status using:"
echo "sudo systemctl status mowbot.service"
