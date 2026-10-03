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
4. Creates `/etc/mowbot.env` (or reuses/migrates existing env files).
5. Logs in to `ghcr.io` with the provided credentials.
6. Pulls images with `docker compose --env-file stack.env --env-file /etc/mowbot.env pull`.
7. Installs the systemd services:
   - `/etc/systemd/system/mowbot_gui.service` (manages Mowbot GUI)
   - `/etc/systemd/system/mowbot_utility_webui.service` (manages Streamlit Utility Control Panel on port `8501`)
   - `/etc/systemd/system/mowbot_mapproxy.service` (manages MapProxy tile cache server on port `8080`)
   Both services set:
   - `User`/`Group` to the installing user
   - `WorkingDirectory` to this clone path
8. Reloads systemd, enables, and restarts all services.

### Verify

```bash
sudo systemctl status mowbot_gui.service mowbot_utility_webui.service mowbot_mapproxy.service
journalctl -u mowbot_utility_webui.service -f
docker compose --env-file stack.env --env-file /etc/mowbot.env ps
```

### Notes

- New `/etc/mowbot.env` defaults: `MB_ROBOT_ID=mowbot_001`, `MB_MANUFACTURER=MowbotTech`, `MB_ROBOT_MODEL=mowbot_model_t2`, `MB_SENSOR_MODEL=mowbot_sensor_kit_t2`, `MB_MQTT_HOST=localhost`, `MB_MQTT_PORT=1883`, `MB_MQTT_USE_TLS=false`.
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
   - `/dev/MB-HITUNE` — **not active yet**: the rule is in the file, commented out, until the USB port of the HiTUNE-I mini on the T4 is known
4. Sets the latency timer of every FTDI FT232R to 8 ms (the HiTUNE-I mini needs it for 100 Hz data without bursts).

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

## Releases: `stack.env`

What software a robot runs is one committed file, [stack.env](stack.env): the ROS image and the GUI image by tag **and digest**, the commit of `mowbot_data` checked out at `/etc/mowbot_data`, and the firmware version the set was soaked with. One commit to it is one robot release; a git tag on that commit names it. Nothing in it is per robot — identity (robot ID and model, MQTT) stays in `/etc/mowbot.env`, which is read by compose *after* `stack.env` and must not repeat its keys (`update.sh` warns).

To release: change the tags and digests in `stack.env` in one commit (digests from `docker buildx imagetools inspect <image:tag> --format '{{.Manifest.Digest}}'`), tag it, and on each robot check that tag out and run `update.sh`. The ROS image's own source manifest lives in the `mowbot` repository (`releases/<version>.repos`, baked into the image as `/opt/mowbot/manifest.repos`).

## GPU and TensorRT engines

The four ROS containers run with `runtime: nvidia` (CUDA and TensorRT libraries come from the host), and `scripts/check_host.sh` — run by install and update — refuses a host that is not L4T R36 or has no `nvidia` docker runtime, and prints the host's L4T release each time. It warns when the host is not the exact release in `stack.env` (`MB_L4T_RELEASE`, the release the stack was tested on: R36.5.2) and when the L4T kernel is not on hold (`sudo apt-mark hold nvidia-l4t-kernel nvidia-l4t-kernel-dtbs nvidia-l4t-kernel-headers`): a kernel upgrade drops out-of-tree USB-serial drivers.

A TensorRT `.engine` is bound to the TensorRT version that built it (the `runtime` image carries 10.3) and tuned to the GPU, so engines are built on the robot, once, from an ONNX model under `/etc/mowbot_data`:

```bash
scripts/build_engine.sh model_artifacts/<model>.onnx model_artifacts/<model>.engine --fp16
```

It runs `trtexec` from the ROS image pinned in `stack.env`. Never copy an engine from a machine with another TensorRT.

## Update

### Run

```bash
git fetch && git checkout <release tag, or main>   # the release to apply is what is checked out
./scripts/update.sh
```

Rolling back is the same with the previous tag.

### What It Does

1. Reads `stack.env` and prints the release it is about to apply; warns if `/etc/mowbot.env` overrides any of its keys.
2. Optionally re-runs the `/etc/mowbot.env` prompts from install (robot ID/model, MQTT settings); press Enter to keep each current value. Settings it does not ask about (`MB_ROS_DOMAIN_ID`, for one) are kept in the rewritten file.
3. Checks `/etc/mowbot_data` out at the commit the release pins. **It refuses to run over local changes there** and lists them: commit them (for example on a branch `robot/<id>`) and make a release that pins that commit, or discard them with `--reset-data`. Silent drift between robots is exactly what this prevents.
4. Pulls the pinned images with `docker compose --env-file stack.env --env-file /etc/mowbot.env pull`.
5. Recreates the ROS stack containers (`mowbot_uros_agent`, bringup, localization, navigation, app) with `up --force-recreate --no-start` (new images, left stopped).
6. Restarts `mowbot_gui.service`, `mowbot_utility_webui.service`, and `mowbot_mapproxy.service` with `sudo systemctl restart`.

### Verify

```bash
sudo systemctl status mowbot_gui.service mowbot_utility_webui.service mowbot_mapproxy.service
docker compose --env-file stack.env --env-file /etc/mowbot.env ps
git -C /etc/mowbot_data log -1 --oneline          # must be the commit in stack.env
docker run --rm --entrypoint cat ghcr.io/serene4mr/mowbot:$(sed -n 's/^MB_IMAGE_TAG=//p' stack.env) /opt/mowbot/build_info
journalctl -u mowbot_utility_webui.service -n 50 --no-pager
```

### Notes

- Update assumes the stack was installed first and `/etc/mowbot.env` exists.
- After update, start stack containers when ready, e.g. `docker start mowbot_uros_agent mowbot_bringup_and_sensing mowbot_localization mowbot_navigation mowbot_app`.
- `mowbot-utility-webui` and `mapproxy` are not pinned yet (`:latest` in `docker-compose.yml`).

## Uninstall

### Run

```bash
./scripts/uninstall.sh
```

### What It Does

1. Stops and disables `mowbot_gui.service`, `mowbot_utility_webui.service`, and `mowbot_mapproxy.service` if present.
2. Removes their systemd service files, reloads systemd, and deletes `/tmp/mowbot-xauth.env`.
3. Brings down containers with `docker compose --env-file stack.env --env-file /etc/mowbot.env down`.
4. Optionally removes `/etc/mowbot.env` (prompted; created by `install.sh`).
5. Optionally removes Mosquitto packages and config, including `hivemq-bridge.conf` if present (prompted).

### Verify

```bash
sudo systemctl status mowbot_gui.service mowbot_utility_webui.service mowbot_mapproxy.service || true
docker compose --env-file stack.env --env-file /etc/mowbot.env ps
```

### Notes

- `/etc/mowbot.env` removal is optional (default: keep) so you can reinstall without re-entering robot/MQTT settings.
- Mosquitto removal is optional and only runs if you confirm the prompt.
- Install also creates `/etc/mowbot_data` and udev rules; uninstall does not remove those. When running the installer again, it will prompt you to choose whether to reset the data directory to default (discarding local changes) or keep/update it.
