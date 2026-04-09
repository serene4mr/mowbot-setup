# mowbot-setup

## Install

### Run

Run from the repository root:

```bash
GHCR_USERNAME=<your_github_user> GHCR_PAT=<read_packages_pat> ./scripts/install.sh
```

If `GHCR_USERNAME`/`GHCR_PAT` are not provided, the installer prompts for them.

### What It Does

1. Verifies Docker is installed and accessible.
2. Installs and configures Mosquitto (`1883`, anonymous access enabled).
3. Creates `mowbot.env` (or reuses/migrates existing env files).
4. Logs in to `ghcr.io` with the provided credentials.
5. Pulls images with `docker compose --env-file mowbot.env pull`.
6. Installs `/etc/systemd/system/mowbot.service` and sets:
   - `User`/`Group` to the installing user
   - `WorkingDirectory` to this clone path
7. Reloads systemd, enables, and restarts `mowbot.service`.

### Verify

```bash
sudo systemctl status mowbot.service
journalctl -u mowbot.service -f
docker compose --env-file mowbot.env ps
```

### Notes

- New `mowbot.env` defaults: `MB_ROBOT_ID=mowbot_001`, `MB_MANUFACTURER=MowbotTech`, `MB_ROBOT_MODEL=mowbot_model_t2`, `MB_SENSOR_MODEL=mowbot_sensor_kit_t2`, `MB_MQTT_HOST=localhost`, `MB_MQTT_PORT=1883`, `MB_MQTT_USE_TLS=false`.
- `MB_MQTT_USE_TLS` is set to `true` only if TLS prompt is answered with `y`, `yes`, `true`, or `1`.
- `MB_DATA_PATH` is left blank for manual configuration.

## Update

### Run

```bash
./scripts/update.sh
```

### What It Does

1. Switches to the repository root.
2. Pulls latest images with `docker compose --env-file mowbot.env pull`.
3. Restarts `mowbot.service` with `sudo systemctl restart mowbot.service`.

### Verify

```bash
sudo systemctl status mowbot.service
docker compose --env-file mowbot.env ps
journalctl -u mowbot.service -n 50 --no-pager
```

### Notes

- Update assumes the stack was installed first and `mowbot.env` exists.

## Uninstall

### Run

```bash
./scripts/uninstall.sh
```

### What It Does

1. Stops and disables `mowbot.service` if present.
2. Removes `/etc/systemd/system/mowbot.service` and reloads systemd.
3. Brings down containers with `docker compose --env-file mowbot.env down`.
4. Optionally removes Mosquitto packages and config (prompted).

### Verify

```bash
sudo systemctl status mowbot.service || true
docker compose --env-file mowbot.env ps
```

### Notes

- The Mosquitto removal step is optional and only runs if you confirm the prompt.
