# 🚜 Mowbot (MB) Udev Configuration Guide

This directory contains the configuration files and scripts required to map the Mowbot's sensors (GPS, IMU, LiDAR) to fixed device names in `/dev/`. This ensures that the software always finds the correct sensor regardless of the order in which they are powered on.

## ⚠️ Critical Requirement: Hardware Topology
Because these rules are tied to the **physical USB port** (`ID_PATH`), each sensor **must** be plugged into its assigned slot. If a sensor is moved to a different port, the system will fail to create the symlink.

| Sensor | Port ID (internal) | Assigned Symlink |
| :--- | :--- | :--- |
| **GPS (Main)** | `2.2.1` | `/dev/MB-UM982` |
| **GPS (RTCM)** | `2.2.4` | `/dev/MB-UM982-RTCM` |
| **IMU (HWT905)** | `2.1.3` | `/dev/MB-HWT905` |
| **LiDAR (C2)** | `2.1.4` | `/dev/MB-RPLIDAR-C2` |

---

## 1. Files in this Directory
*   `99-mowbot-udev.rules`: The rule definition file using the `MB-` prefix.
*   `create_udev_rules.sh`: Script to install and activate the rules.
*   `delete_udev_rules.sh`: Script to remove the rules from the system.

---

## 2. Installation Setup
Before running the scripts, ensure they have execution permissions:
```bash
chmod +x create_udev_rules.sh delete_udev_rules.sh
```

### Apply the Rules
```bash
sudo ./create_udev_rules.sh
```

---

## 3. Verification
Verify that all Mowbot devices have been mapped correctly:
```bash
ls -l /dev/MB-*
```

---

## 4. Troubleshooting

### 🔄 The "Replug & Reboot" Rule
On this system, the `udev` daemon often fails to process "Hotplug" events live. If you unplug a device and plug it back in, the symlink will likely disappear and not return automatically.
*   **Step 1 (Manual Trigger):** Try running `sudo udevadm trigger`.
*   **Step 2 (Reboot):** If Step 1 fails, **perform a full system reboot.** This is the only 100% reliable way to force the kernel to re-map the physical USB paths to the Mowbot symlinks.
    ```bash
    sudo reboot
    ```

### 🛑 Connection Timed Out
If you see the error `Failed to wait for daemon to reply: Connection timed out`:
*   The `udev` control socket is deadlocked. 
*   **Fix:** Restart the service manually to unblock it: `sudo systemctl restart systemd-udevd`.

### 🔍 Check Physical Path
If hardware has changed (e.g., a new USB Hub), verify the current `ID_PATH` to update the rules:
```bash
udevadm info -q property -n /dev/ttyUSB0 | grep ID_PATH=
```

---

## 5. Uninstallation
To remove the Mowbot rules and revert to default system naming:
```bash
sudo ./delete_udev_rules.sh
```

