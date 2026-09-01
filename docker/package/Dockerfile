# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE
FROM ${BASE_IMAGE} AS builder

ARG ROS_DISTRO=humble
ARG REPOSITORY_URL
ARG REPOSITORY_REF=main
ARG CUDA_ARCHITECTURES
ARG ENABLE_CUDA=ON
ARG CMAKE_BUILD_TYPE=Release
ARG EXTRA_CMAKE_ARGS=""
ARG COLCON_PACKAGES_SELECT=""
ARG ROSDEP_SKIP_KEYS=""
ARG PACKAGE_CONFIG=default
ARG TARGETPLATFORM
ARG TARGETARCH

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /opt/ros_ws

RUN test -n "${REPOSITORY_URL}" \
    && test -n "${CUDA_ARCHITECTURES}" \
    && [[ "${PACKAGE_CONFIG}" =~ ^[a-zA-Z0-9._-]+$ ]]

RUN mkdir -p src/package \
    && git -C src/package init \
    && git -C src/package remote add origin "${REPOSITORY_URL}" \
    && git -C src/package fetch --depth 1 origin "${REPOSITORY_REF}" \
    && git -C src/package checkout --detach FETCH_HEAD \
    && git -C src/package submodule update --init --recursive --depth 1

COPY config/packages /tmp/package-config

RUN mkdir -p /opt/package-deps \
    && if [[ -f "/tmp/package-config/${PACKAGE_CONFIG}.repos" ]]; then \
         vcs import src < "/tmp/package-config/${PACKAGE_CONFIG}.repos"; \
       fi \
    && if [[ -f "/tmp/package-config/${PACKAGE_CONFIG}.prebuild.sh" ]]; then \
         bash "/tmp/package-config/${PACKAGE_CONFIG}.prebuild.sh"; \
       fi

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
    && ROSDEP_ARGS=( \
        --from-paths src \
        --ignore-src \
        --rosdistro "${ROS_DISTRO}" \
        --recursive \
        --yes \
    ) \
    && if [[ -n "${ROSDEP_SKIP_KEYS}" ]]; then \
         ROSDEP_ARGS+=(--skip-keys "${ROSDEP_SKIP_KEYS}"); \
       fi \
    && rosdep install "${ROSDEP_ARGS[@]}"

RUN --mount=type=cache,target=/root/.ccache,sharing=locked \
    source "/opt/ros/${ROS_DISTRO}/setup.bash" \
    && export CCACHE_DIR=/root/.ccache \
    && export CMAKE_PREFIX_PATH="/opt/package-deps:${CMAKE_PREFIX_PATH:-}" \
    && export LD_LIBRARY_PATH="/opt/package-deps/lib:${LD_LIBRARY_PATH:-}" \
    && CMAKE_ARGS=( \
        "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}" \
        "-DENABLE_CUDA=${ENABLE_CUDA}" \
        "-DCMAKE_CUDA_ARCHITECTURES=${CUDA_ARCHITECTURES}" \
        "-DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc" \
        "-DCMAKE_C_COMPILER_LAUNCHER=ccache" \
        "-DCMAKE_CXX_COMPILER_LAUNCHER=ccache" \
        "-DCMAKE_CUDA_COMPILER_LAUNCHER=ccache" \
    ) \
    && EXTRA_ARGS=() \
    && if [[ -n "${EXTRA_CMAKE_ARGS}" ]]; then \
         read -r -a EXTRA_ARGS <<< "${EXTRA_CMAKE_ARGS}"; \
       fi \
    && PACKAGE_ARGS=() \
    && if [[ -n "${COLCON_PACKAGES_SELECT}" ]]; then \
         read -r -a SELECTED_PACKAGES <<< "${COLCON_PACKAGES_SELECT}"; \
         PACKAGE_ARGS=(--packages-select "${SELECTED_PACKAGES[@]}"); \
       fi \
    && colcon build \
        --merge-install \
        --event-handlers console_direct+ \
        "${PACKAGE_ARGS[@]}" \
        --cmake-args "${CMAKE_ARGS[@]}" "${EXTRA_ARGS[@]}"

FROM ${BASE_IMAGE} AS runtime

ARG ROS_DISTRO=humble
ARG REPOSITORY_URL
ARG REPOSITORY_REF=main
ARG CUDA_ARCHITECTURES
ARG ROSDEP_SKIP_KEYS=""
ARG PACKAGE_CONFIG=default
ARG TARGETPLATFORM
ARG TARGETARCH

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --from=builder /opt/package-deps /opt/package-deps

RUN --mount=type=bind,from=builder,source=/opt/ros_ws/src,target=/tmp/ros_ws/src \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
    && ROSDEP_ARGS=( \
        --from-paths /tmp/ros_ws/src \
        --ignore-src \
        --rosdistro "${ROS_DISTRO}" \
        --recursive \
        --yes \
    ) \
    && if [[ -n "${ROSDEP_SKIP_KEYS}" ]]; then \
         ROSDEP_ARGS+=(--skip-keys "${ROSDEP_SKIP_KEYS}"); \
       fi \
    && rosdep install "${ROSDEP_ARGS[@]}"

COPY --from=builder /opt/ros_ws/install /opt/ros_ws/install

LABEL io.armmeh.package.repository="${REPOSITORY_URL}" \
      io.armmeh.package.revision="${REPOSITORY_REF}" \
      io.armmeh.package.config="${PACKAGE_CONFIG}" \
      io.armmeh.target.platform="${TARGETPLATFORM}" \
      io.armmeh.target.architecture="${TARGETARCH}" \
      io.armmeh.cuda.architectures="${CUDA_ARCHITECTURES}"

ENV ROS_DISTRO=${ROS_DISTRO} \
    CUDA_ARCHITECTURES=${CUDA_ARCHITECTURES}

WORKDIR /workspace

CMD ["bash"]
