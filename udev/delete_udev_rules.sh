#!/bin/bash

echo "Deleting remap rules for mowbot..."
sudo rm -f /etc/udev/rules.d/99-mowbot-udev.rules

echo "Reloading udev rules..."
sudo udevadm control --reload-rules
sudo udevadm trigger

echo "Finish delete!"