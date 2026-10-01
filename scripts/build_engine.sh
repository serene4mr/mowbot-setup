#!/bin/bash
# Builds a TensorRT engine on this robot, with the TensorRT of the ROS image
# this release pins (stack.env), from an ONNX model under /etc/mowbot_data.
#
# An .engine file deserializes only under the TensorRT version that built it
# and is tuned to the GPU it was built on, so engines are built here, once,
# and never copied from a machine with another TensorRT. Usage:
#
#   scripts/build_engine.sh model_artifacts/<model>.onnx model_artifacts/<model>.engine [trtexec options]
#
# Paths are relative to /etc/mowbot_data. Extra options go to trtexec
# (e.g. --fp16). Takes minutes on an Orin NX.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
cd "$DIR"

if [ $# -lt 2 ]; then
    sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
fi
onnx=$1; engine=$2; shift 2

# shellcheck disable=SC1091
source stack.env
image="ghcr.io/serene4mr/mowbot:${MB_IMAGE_TAG:?set in stack.env}@${MB_IMAGE_DIGEST:?set in stack.env}"
data="${MB_DATA_PATH:-/etc/mowbot_data}"

[ -f "$data/$onnx" ] || { echo "Error: $data/$onnx not found." >&2; exit 1; }

echo "Building $engine from $onnx with the TensorRT of $MB_IMAGE_TAG ..."
docker run --rm --runtime nvidia \
    -v "$data:/etc/mowbot_data" \
    --entrypoint /usr/src/tensorrt/bin/trtexec \
    "$image" \
    --onnx="/etc/mowbot_data/$onnx" --saveEngine="/etc/mowbot_data/$engine" "$@"
echo "Wrote $data/$engine"
