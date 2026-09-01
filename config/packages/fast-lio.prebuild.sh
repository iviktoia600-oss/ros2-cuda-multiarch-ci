#!/usr/bin/env bash
set -euo pipefail

SDK_URL="https://github.com/Livox-SDK/Livox-SDK2.git"
SDK_REF="08f523c930b2f0ba1e98a6afaa8d7476bf479908"
SDK_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${SDK_DIR}"
}
trap cleanup EXIT

git -C "${SDK_DIR}" init
git -C "${SDK_DIR}" remote add origin "${SDK_URL}"
git -C "${SDK_DIR}" fetch --depth 1 origin "${SDK_REF}"
git -C "${SDK_DIR}" checkout --detach FETCH_HEAD

cmake \
  -S "${SDK_DIR}" \
  -B "${SDK_DIR}/build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/opt/package-deps

cmake --build "${SDK_DIR}/build" --parallel "$(nproc)"
cmake --install "${SDK_DIR}/build"

DRIVER_DIR="/opt/ros_ws/src/livox_ros_driver2"

test -d "${DRIVER_DIR}"
cp "${DRIVER_DIR}/package_ROS2.xml" "${DRIVER_DIR}/package.xml"
mkdir -p "${DRIVER_DIR}/launch"
cp -a "${DRIVER_DIR}/launch_ROS2/." "${DRIVER_DIR}/launch/"
