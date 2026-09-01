#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

PACKAGE="${1:-}"
PROFILE="${2:-}"
MODE="${3:-check}"

usage() {
  echo "Использование: $0 <пакет> <профиль> [check|load|push]"
  echo "Пример: $0 fast-lio x86 check"
}

if [[ ! "${PACKAGE}" =~ ^[a-z0-9][a-z0-9._-]*$ ]] \
  || [[ ! "${PROFILE}" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then
  usage
  exit 2
fi

case "${MODE}" in
  check|load|push) ;;
  *)
    usage
    exit 2
    ;;
esac

PACKAGE_FILE="config/packages/${PACKAGE}.env"
PROFILE_FILE="config/platforms/${PROFILE}.env"

for file in "${PACKAGE_FILE}" "${PROFILE_FILE}"; do
  if [[ ! -f "${file}" ]]; then
    echo "Файл конфигурации не найден: ${file}" >&2
    exit 1
  fi
done

# shellcheck disable=SC1090
source "${PROFILE_FILE}"
# shellcheck disable=SC1090
source "${PACKAGE_FILE}"

REQUIRED_VARIABLES=(
  PLATFORM_ID
  TARGET_PLATFORM
  BASE_BUILD_ARG_VALUE
  BASE_IMAGE_NAME
  BASE_IMAGE_TAG
  CUDA_ARCHITECTURES
  PACKAGE_CONFIG
  REPOSITORY_URL
  REPOSITORY_REF
)

for variable in "${REQUIRED_VARIABLES[@]}"; do
  if [[ -z "${!variable:-}" ]]; then
    echo "Отсутствует переменная: ${variable}" >&2
    exit 1
  fi
done

if [[ "${PACKAGE_CONFIG}" != "${PACKAGE}" ]]; then
  echo "PACKAGE_CONFIG должен совпадать с именем профиля пакета" >&2
  exit 1
fi

command -v docker >/dev/null
docker buildx version >/dev/null

ROS_DISTRO="${ROS_DISTRO:-humble}"
ENABLE_CUDA="${ENABLE_CUDA:-ON}"
CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}"
EXTRA_CMAKE_ARGS="${EXTRA_CMAKE_ARGS:-}"
COLCON_PACKAGES_SELECT="${COLCON_PACKAGES_SELECT:-}"
ROSDEP_SKIP_KEYS="${ROSDEP_SKIP_KEYS:-}"

IMAGE_REGISTRY="${IMAGE_REGISTRY:-local}"
IMAGE_NAMESPACE="${IMAGE_NAMESPACE:-armmeh}"
IMAGE_NAMESPACE="${IMAGE_NAMESPACE,,}"

if [[ "${MODE}" == "check" ]]; then
  BASE_IMAGE="${BASE_IMAGE:-${BASE_BUILD_ARG_VALUE}}"
else
  BASE_IMAGE="${BASE_IMAGE:-${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}}"
fi

PACKAGE_IMAGE_NAME="${PACKAGE_IMAGE_NAME:-ros2-cuda-${PACKAGE_CONFIG}-${PLATFORM_ID}}"
PACKAGE_IMAGE_TAG="${PACKAGE_IMAGE_TAG:-latest}"
IMAGE_REF="${IMAGE_REF:-${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/${PACKAGE_IMAGE_NAME}:${PACKAGE_IMAGE_TAG}}"

BUILD_COMMAND=(
  docker buildx build
  --platform "${TARGET_PLATFORM}"
  --file docker/package/Dockerfile
  --build-arg "BASE_IMAGE=${BASE_IMAGE}"
  --build-arg "ROS_DISTRO=${ROS_DISTRO}"
  --build-arg "PACKAGE_CONFIG=${PACKAGE_CONFIG}"
  --build-arg "REPOSITORY_URL=${REPOSITORY_URL}"
  --build-arg "REPOSITORY_REF=${REPOSITORY_REF}"
  --build-arg "CUDA_ARCHITECTURES=${CUDA_ARCHITECTURES}"
  --build-arg "ENABLE_CUDA=${ENABLE_CUDA}"
  --build-arg "CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
  --build-arg "EXTRA_CMAKE_ARGS=${EXTRA_CMAKE_ARGS}"
  --build-arg "COLCON_PACKAGES_SELECT=${COLCON_PACKAGES_SELECT}"
  --build-arg "ROSDEP_SKIP_KEYS=${ROSDEP_SKIP_KEYS}"
  --tag "${IMAGE_REF}"
)

if [[ -n "${CACHE_FROM:-}" ]]; then
  BUILD_COMMAND+=(--cache-from "${CACHE_FROM}")
fi

if [[ -n "${CACHE_TO:-}" ]]; then
  BUILD_COMMAND+=(--cache-to "${CACHE_TO}")
fi

case "${MODE}" in
  check)
    BUILD_COMMAND+=(--check)
    ;;
  load)
    BUILD_COMMAND+=(--load)
    ;;
  push)
    BUILD_COMMAND+=(--push --provenance=true --sbom=true)
    ;;
esac

BUILD_COMMAND+=(.)

echo "Пакет: ${PACKAGE_CONFIG}"
echo "Платформа: ${PLATFORM_ID} (${TARGET_PLATFORM})"
echo "CUDA SM: ${CUDA_ARCHITECTURES}"
echo "Базовый образ: ${BASE_IMAGE}"
echo "Результат: ${IMAGE_REF}"
echo "Режим: ${MODE}"

"${BUILD_COMMAND[@]}"
