#!/bin/bash
# Checks the robot host before the stack is installed or updated. Run by
# install.sh and update.sh; can be run alone.
#
# The ROS images are built for L4T R36 and run CUDA/TensorRT through the
# nvidia container runtime (the driver and libraries such as
# libnvdla_compiler.so come from the host at run time). docker-compose.yml
# asks for that runtime explicitly, so a host without it refuses to create
# the containers instead of running them without a GPU; this check says so
# before compose does, and prints the L4T release so that every install or
# update records what the robot runs.
set -euo pipefail

status=0

if [ -r /etc/nv_tegra_release ]; then
    l4t=$(head -1 /etc/nv_tegra_release)
    major=$(sed -n 's/^# R\([0-9]*\) (release).*/\1/p' /etc/nv_tegra_release)
    echo "Host L4T: ${l4t#\# }"
    if [ "$major" != "36" ]; then
        echo "Error: the images are built for L4T R36; this host is R${major:-unknown}." >&2
        status=1
    fi
    # The exact release the stack was soaked on is pinned in stack.env
    # (MB_L4T_RELEASE). Another R36 release runs the same images, so a
    # difference is a warning, not a refusal: it means this robot runs a
    # combination nobody tested.
    revision=$(sed -n 's/.*REVISION: \([0-9.]*\),.*/\1/p' /etc/nv_tegra_release)
    release="${major}.${revision}"
    expected=$(sed -n 's/^MB_L4T_RELEASE=//p' "$(dirname "$0")/../stack.env" 2>/dev/null || true)
    if [ -n "$expected" ] && [ "$release" != "$expected" ]; then
        echo "Warning: this release was tested on L4T R${expected}; this host is R${release}." >&2
    fi
    # A kernel upgrade drops out-of-tree USB-serial modules, and with them
    # sensors on CH340/PL2303 adapters: the kernel packages stay on hold.
    if command -v apt-mark >/dev/null && ! apt-mark showhold 2>/dev/null | grep -qx 'nvidia-l4t-kernel'; then
        echo "Warning: the L4T kernel is not on hold; an 'apt upgrade' can change it. To hold it:" >&2
        echo "  sudo apt-mark hold nvidia-l4t-kernel nvidia-l4t-kernel-dtbs nvidia-l4t-kernel-headers" >&2
    fi
else
    echo "Error: /etc/nv_tegra_release not found; this is not an NVIDIA L4T (Jetson) host." >&2
    status=1
fi

if docker info --format '{{json .Runtimes}}' 2>/dev/null | grep -q '"nvidia"'; then
    echo "Docker runtimes: nvidia present (default: $(docker info --format '{{.DefaultRuntime}}'))"
else
    echo "Error: docker has no 'nvidia' runtime; the ROS containers need it for CUDA/TensorRT." >&2
    echo "Install nvidia-container-toolkit (JetPack ships it) and check /etc/docker/daemon.json." >&2
    status=1
fi

exit $status
