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
3. Optionally configures a HiveMQ bridge in `/etc/mosquitto/conf.d/hivemq-bridge.conf`.
4. Creates `mowbot.env` (or reuses/migrates existing env files).
5. Logs in to `ghcr.io` with the provided credentials.
6. Pulls images with `docker compose --env-file mowbot.env pull`.
7. Installs `/etc/systemd/system/mowbot_gui.service` and sets:
   - `User`/`Group` to the installing user
   - `WorkingDirectory` to this clone path
8. Reloads systemd, enables, and restarts `mowbot_gui.service`.

### Verify

```bash
sudo systemctl status mowbot_gui.service
journalctl -u mowbot_gui.service -f
docker compose --env-file mowbot.env ps
```

### Notes

- New `mowbot.env` defaults: `MB_ROBOT_ID=mowbot_001`, `MB_MANUFACTURER=MowbotTech`, `MB_ROBOT_MODEL=mowbot_model_t2`, `MB_SENSOR_MODEL=mowbot_sensor_kit_t2`, `MB_MQTT_HOST=localhost`, `MB_MQTT_PORT=1883`, `MB_MQTT_USE_TLS=false`.
- `MB_MQTT_USE_TLS` is set to `true` only if TLS prompt is answered with `y`, `yes`, `true`, or `1`.
- `MB_DATA_PATH` is left blank for manual configuration.
- Installer can optionally configure HiveMQ bridge forwarding. No defaults are applied for HiveMQ values; provide `HIVEMQ_BRIDGE_ADDRESS`, `HIVEMQ_USERNAME`, and `HIVEMQ_PASSWORD` (or enter them interactively) when bridge setup is enabled.

## Hardware Setup (udev)

### Run

From the repository root:

```bash
cd udev
chmod +x create_udev_rules.sh delete_udev_rules.sh
sudo ./create_udev_rules.sh
```

### What It Does

1. Installs `99-mowbot-udev.rules` into `/etc/udev/rules.d/`.
2. Reloads udev rules and triggers device remap.
3. Creates stable sensor symlinks in `/dev/`:
   - `/dev/MB-UM982`
   - `/dev/MB-UM982-RTCM`
   - `/dev/MB-HWT905`
   - `/dev/MB-RPLIDAR-C2`

### Verify

```bash
ls -l /dev/MB-*
```

### Notes

- This step is required for physical robot deployments so sensor device names stay stable.
- Rules are tied to physical USB path (`ID_PATH`), so sensors must stay in assigned ports.
- If symlinks do not appear after replug, run `sudo udevadm trigger`; if still missing, reboot the host.
- After install + udev setup, a reboot is recommended before first field run when device discovery is unstable or `/dev/MB-*` links are missing.
- Quick recovery flow: check `ls -l /dev/MB-*`, run `sudo udevadm trigger`, then reboot if links are still missing.

## Update

### Run

```bash
./scripts/update.sh
```

### What It Does

1. Switches to the repository root.
2. Pulls latest images with `docker compose --env-file mowbot.env pull`.
3. Restarts `mowbot_gui.service` with `sudo systemctl restart mowbot_gui.service`.

### Verify

```bash
sudo systemctl status mowbot_gui.service
docker compose --env-file mowbot.env ps
journalctl -u mowbot_gui.service -n 50 --no-pager
```

### Notes

- Update assumes the stack was installed first and `mowbot.env` exists.

## Uninstall

### Run

```bash
./scripts/uninstall.sh
```

### What It Does

1. Stops and disables `mowbot_gui.service` if present.
2. Removes `/etc/systemd/system/mowbot_gui.service` and reloads systemd.
3. Brings down containers with `docker compose --env-file mowbot.env down`.
4. Optionally removes Mosquitto packages and config (prompted).

### Verify

```bash
sudo systemctl status mowbot_gui.service || true
docker compose --env-file mowbot.env ps
```

### Notes

- The Mosquitto removal step is optional and only runs if you confirm the prompt.
