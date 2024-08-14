#!/usr/bin/env bash
#
# builds linux/<arch> specific docker images,
# and stores compiled binaries in ./bin
#
set -euo pipefail

export DOCKER_BUILDKIT=1
export BUILDKIT_PROGRESS=plain


SCRIPT_DIR="$(realpath $(dirname $0))"
REPO_ROOT="${SCRIPT_DIR}/../.."
BIN_DIR="$(realpath "${REPO_ROOT}")/bin"

# sets git ref when checking out Blacksmoke16/oq,
# default to then value of UPSTREAM_GIT_REF arg set in dist.Dockerfile
: ${UPSTREAM_GIT_REF:-}
: ${IMAGE_BASE:="oq"}
: ${IMAGE_TAG_PREFIX:-}
: ${DOCKER_BUILD_OPTS:-} # pass additional options as env variable
: ${DOCKER_BUILD_ROOT:="${REPO_ROOT}"}
: ${DOCKERFILE:="${SCRIPT_DIR}/dist.Dockerfile"}
: ${BIN_CLEANUP:="true"} # enables removing the context of ./bin before build

: ${TARGET_ARCH_LIST:='["arm64","amd64"]'} # json array of linux/<arch> strings
export TARGET_ARCH_LIST=( $(jq -r .[] <<< ${TARGET_ARCH_LIST} || tr -d '"[]' <<< ${TARGET_ARCH_LIST} | tr ',' ' ' ) )

if [[ "${GITHUB_ACTIONS:-"false"}" == "true" ]]; then
  GA_GROUP_BEGIN="::group::"
  GA_GROUP_END="::endgroup::"
else
  GA_GROUP_BEGIN="## "
fi

# request specific git ref (tag, branch, etc) via build-arg
# if UPSTREAM_GIT_REF env var is set
if [[ -n "${UPSTREAM_GIT_REF:-}" ]]; then
  echo >&2 "## targeting specific OQ version: ${UPSTREAM_GIT_REF}"
  : ${IMAGE_TAG_PREFIX:="${UPSTREAM_GIT_REF}-"}
  export UPSTREAM_GIT_REF
  DOCKER_BUILD_OPTS+=" --build-arg UPSTREAM_GIT_REF"
fi

IMAGE_NAME="${IMAGE_BASE}:${IMAGE_TAG_PREFIX:-}"

echo >&2 "## TARGET_ARCH_LIST: ${TARGET_ARCH_LIST[@]}"
echo >&2 "## IMAGE_TAG_PREFIX: ${IMAGE_TAG_PREFIX:-}"
echo >&2 "## IMAGE_NAME: ${IMAGE_NAME:-}<arch>"

if [[ -d "${BIN_DIR}" ]]; then
  if [[ "${BIN_CLEANUP:-}" == "true" ]]; then
    echo "## cleaning up bin dir (${BIN_DIR})"
    find "${BIN_DIR}" -maxdepth 1 -mindepth 1 -delete
  fi
else
  echo "## creating bin dir (${BIN_DIR})"
  mkdir "${BIN_DIR}"
fi

declare -a IMAGES_BUILT

for arch in ${TARGET_ARCH_LIST[@]}; do
  image="${IMAGE_NAME}${arch}"
  echo "${GA_GROUP_BEGIN}building ${image} for linux/${arch}"
  docker buildx build ${DOCKER_BUILD_OPTS:-} \
    --load \
    --platform linux/${arch} \
    --tag "${image}" \
    --file "${DOCKERFILE}" \
    "${DOCKER_BUILD_ROOT}"
  IMAGES_BUILT+=(${image})
  unset arch image
  echo "${GA_GROUP_END:-}"
done

for arch in ${TARGET_ARCH_LIST[@]}; do
  image="${IMAGE_NAME}${arch}"
  echo "${GA_GROUP_BEGIN}retrieving oq binaries for linux/${arch} from ${image}"
  docker run \
    --platform linux/${arch} \
    --rm \
    --user root \
    --entrypoint /bin/sh \
    --volume "${BIN_DIR}":/mnt/repo/bin \
    --workdir /mnt/repo \
    "${image}" \
    -c 'cp -v $(which oq)-* ./bin/'
    unset arch image
    echo "${GA_GROUP_END:-}"
done

echo "${GA_GROUP_BEGIN}images built"
for image in ${IMAGES_BUILT[@]}; do
  echo "- ${image}"
done
echo "${GA_GROUP_END:-}"

echo "${GA_GROUP_BEGIN}listing content of ./bin"
ls -la "${REPO_ROOT}/bin/"
echo "${GA_GROUP_END:-}"
