# syntax=docker/dockerfile:1.4
#
# NOTE: build root is the root of the repo

ARG CRYSTAL_VERSION="1.13.1"
ARG JQ_VERSION="1.7.1"
ARG OQ_BIN_DIR="/opt/oq/bin"
ARG OQ_BIN_USE_TARGETARCH="false"

# base for building the binary
FROM 84codes/crystal:${CRYSTAL_VERSION}-alpine AS build-base
LABEL description="This text illustrates \
that label-values can span multiple lines."
RUN apk add \
      --update \
      --upgrade \
      --no-cache \
      --force-overwrite \
      git bash curl jq \
      libxml2-dev libxml2-static yaml-dev yaml-static xz-static zlib-static

# builds the binaries
FROM build-base AS build
ARG JQ_VERSION OQ_BIN_DIR OQ_BIN_USE_TARGETARCH TARGETARCH
WORKDIR /src
SHELL ["/bin/bash", "-uo", "pipefail", "-c"]
RUN --mount=type=bind,source=.,target=/src,rw <<-SCRIPT
    #!/usr/bin/env bash
    mkdir -p "${OQ_BIN_DIR}"
    echo >&2 "## downloading jq"
    JQ_REPO="jqlang/jq"
    if [[ -z "${JQ_VERSION:-}" ]] || [[ "${JQ_VERSION}" == "latest" ]]; then
      JQ_VERSION="$(curl -sSLq "https://api.github.com/repos/${JQ_REPO}/releases/latest" | jq -r .tag_name)"
    fi
    echo "### JQ_VERSION: ${JQ_VERSION}"
    wget -qO "${OQ_BIN_DIR}/jq" \
      "https://github.com/${JQ_REPO}/releases/download/jq-${JQ_VERSION}/jq-linux-${TARGETARCH}"
    chmod +x "${OQ_BIN_DIR}/jq"
    "${OQ_BIN_DIR}/jq" --version || exit 1
    echo >&2 "## resolving OQ version"
    OQ_VERSION="$(git describe --exact-match --tags HEAD 2>/dev/null)"
    if [[ $? -eq 0 ]]; then
      echo >&2 "### the HEAD is tagged"
    else
      echo >&2 "### the HEAD is not tagged"
      OQ_VERSION="$(git rev-parse --short=8 HEAD)"
      if [[ $? -ne 0 ]]; then
        echo >&2 "### failed to get the SHA of the HEAD"
        exit 1
      fi
    fi
    if ! git diff --quiet; then
      OQ_VERSION+="-dirty"
    fi
    echo >&2 "## building oq ${OQ_VERSION} for linux/${TARGETARCH}"
    shards build \
      --production \
      --release \
      --static \
      --no-debug \
      --link-flags="-s -Wl,-z,relro,-z,now"
    OQ_BIN="${OQ_BIN_DIR}/oq-${OQ_VERSION}-linux-$(uname -m)"
    cp ./bin/oq "${OQ_BIN}"
    echo >&2 "## verifying OQ binary and checking version"
    oq --version
    echo >&2 "## recording "
SCRIPT

# final release
FROM busybox:stable-musl AS release
LABEL org.opencontainers.image.source=https://github.com/anapsix/Blacksmoke16-oq-releases
LABEL org.opencontainers.image.description="From https://github.com/Blacksmoke16/oq. A performant, portable jq wrapper that facilitates the consumption and output of formats other than JSON; using jq filters to transform the data."
LABEL org.opencontainers.image.licenses=MIT
ARG OQ_BIN_DIR JQ_VERSION TARGETARCH
ENV JQ_VERSION=${JQ_VERSION}
COPY --link --from=build ${OQ_BIN_DIR}/oq* ${OQ_BIN_DIR}/jq* /usr/local/bin/
RUN <<-SCRIPT
  #!/usr/bin/env sh
  set -euo pipefail
  UNAME_M="$(uname -m)"
  cd /usr/local/bin
  native_arch_bin="$(find . -type f -name "oq-*")"
  ls -la
  echo "native_arch_bin: ${native_arch_bin}"
  ln "${native_arch_bin}" oq
  OQ_VERSION="$(oq --version | oq -i yaml -r .oq)"
  target_arch_bin="oq-v${OQ_VERSION}-linux-${TARGETARCH}"
  ln "${native_arch_bin}" "${target_arch_bin}"
  echo "export OQ_VERSION=${OQ_VERSION}" > /etc/profile
SCRIPT
USER nobody
WORKDIR /home
ENTRYPOINT ["/bin/sh", "-l"]
