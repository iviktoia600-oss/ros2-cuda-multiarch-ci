# syntax=docker/dockerfile:1.7

ARG L4T_CUDA_IMAGE=nvcr.io/nvidia/l4t-cuda:12.6.11-runtime
FROM ${L4T_CUDA_IMAGE}

ARG ROS_DISTRO=humble
ARG ROS_APT_SOURCE_VERSION=1.2.0
ARG CUDA_TOOLKIT_PACKAGE=cuda-toolkit-12-6
ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH

LABEL io.armmeh.target.device="Jetson AGX Orin 64GB" \
      io.armmeh.target.jetpack="6.2.2" \
      io.armmeh.target.l4t="36.5.0" \
      io.armmeh.target.cuda="12.6"

ENV ROS_DISTRO=${ROS_DISTRO} \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    CUDA_HOME=/usr/local/cuda \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN test "${TARGETARCH}" = "arm64"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        locales \
        software-properties-common \
        ${CUDA_TOOLKIT_PACKAGE} \
    && locale-gen en_US en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
    && add-apt-repository universe \
    && curl -fsSL \
        -o /tmp/ros2-apt-source.deb \
        "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.jammy_all.deb" \
    && dpkg -i /tmp/ros2-apt-source.deb \
    && rm -f /tmp/ros2-apt-source.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ccache \
        cmake \
        git \
        ninja-build \
        python3-colcon-common-extensions \
        python3-pip \
        python3-rosdep \
        ros-dev-tools \
        ros-${ROS_DISTRO}-ros-base \
    && rm -rf /var/lib/apt/lists/*

RUN rosdep init 2>/dev/null || true \
    && rosdep update --rosdistro ${ROS_DISTRO}

COPY scripts/ros_entrypoint.sh /ros_entrypoint.sh
RUN chmod +x /ros_entrypoint.sh

RUN nvcc --version \
    && source "/opt/ros/${ROS_DISTRO}/setup.bash" \
    && ros2 --help >/dev/null

WORKDIR /workspace

ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["bash"]
