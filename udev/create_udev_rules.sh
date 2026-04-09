#!/bin/bash

WORKING_DIR=$(dirname $(readlink -f $0))
cd $WORKING_DIR

echo "Remapping the device serial ports of mowbot..."
echo "Copying 99-mowbot-udev.rules to /etc/udev/rules.d/"
sudo cp ${WORKING_DIR}/99-mowbot-udev.rules /etc/udev/rules.d/99-mowbot-udev.rules

echo "Reloading udev rules..."
sudo udevadm control --reload-rules
sudo udevadm trigger

echo "Finish!"