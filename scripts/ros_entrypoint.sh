#!/usr/bin/env bash
set -e

source "/opt/ros/${ROS_DISTRO}/setup.bash"

export CMAKE_PREFIX_PATH="/opt/package-deps:${CMAKE_PREFIX_PATH:-}"
export LD_LIBRARY_PATH="/opt/package-deps/lib:${LD_LIBRARY_PATH:-}"

if [[ -f /opt/ros_ws/install/setup.bash ]]; then
  source /opt/ros_ws/install/setup.bash
fi

if [[ -f /workspace/install/setup.bash ]]; then
  source /workspace/install/setup.bash
fi

exec "$@"
