#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

PROFILE="${1:-}"
MODE="${2:-check}"

usage() {
  echo "Использование: $0 <профиль> [check|load|push]"
  echo "Профили: x86, agx-orin-jp62, orin-nano-jp72"
}

if [[ ! "${PROFILE}" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then
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

PROFILE_FILE="config/platforms/${PROFILE}.env"

if [[ ! -f "${PROFILE_FILE}" ]]; then
  echo "Профиль не найден: ${PROFILE_FILE}" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "${PROFILE_FILE}"

REQUIRED_VARIABLES=(
  PLATFORM_ID
  TARGET_PLATFORM
  BASE_DOCKERFILE
  BASE_BUILD_ARG_NAME
  BASE_BUILD_ARG_VALUE
  BASE_IMAGE_NAME
  BASE_IMAGE_TAG
)

for variable in "${REQUIRED_VARIABLES[@]}"; do
  if [[ -z "${!variable:-}" ]]; then
    echo "В профиле отсутствует переменная: ${variable}" >&2
    exit 1
  fi
done

command -v docker >/dev/null
docker buildx version >/dev/null

IMAGE_REGISTRY="${IMAGE_REGISTRY:-local}"
IMAGE_NAMESPACE="${IMAGE_NAMESPACE:-armmeh}"
IMAGE_REF="${IMAGE_REF:-${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}}"

BUILD_COMMAND=(
  docker buildx build
  --platform "${TARGET_PLATFORM}"
  --file "${BASE_DOCKERFILE}"
  --build-arg "${BASE_BUILD_ARG_NAME}=${BASE_BUILD_ARG_VALUE}"
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

echo "Профиль: ${PLATFORM_ID}"
echo "Платформа: ${TARGET_PLATFORM}"
echo "Образ: ${IMAGE_REF}"
echo "Режим: ${MODE}"

"${BUILD_COMMAND[@]}"
