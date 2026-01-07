# Base worker image for act CI runs with Agda and pandoc preinstalled.
# Inherits from the standard act runner image (ubuntu 22.04).

FROM catthehacker/ubuntu:act-22.04 AS agda-builder
ARG AGDA_VERSION=2.8.0

ENV DEBIAN_FRONTEND=noninteractive

# Core tooling for our workflows: build Agda 2.8.0 + stdlib + pandoc.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        cabal-install \
        ghc \
        libffi-dev \
        libgmp-dev \
        libncurses-dev \
        zlib1g-dev \
        ca-certificates \
        curl \
        git \
        pandoc \
        agda-stdlib \
    && rm -rf /var/lib/apt/lists/*

# Build and install Agda 2.8.0 (avoids Ubuntu's older 2.6.x packages).
# Uses BuildKit cache mounts so repeated builds only download/compile deltas.
RUN mkdir -p /opt/agda/bin

RUN --mount=type=cache,target=/root/.cabal \
    --mount=type=cache,target=/root/.cache \
    cabal update

RUN --mount=type=cache,target=/root/.cabal \
    --mount=type=cache,target=/root/.cache \
    cabal install alex happy

RUN --mount=type=cache,target=/root/.cabal \
    --mount=type=cache,target=/root/.cache \
    cabal install Agda-${AGDA_VERSION} --installdir=/opt/agda/bin --install-method=copy

RUN set -e \
 && AGDA_DIR="$(agda --print-agda-dir)" \
 && mkdir -p /opt/agda/lib \
 && cp -r "$AGDA_DIR/lib/prim" /opt/agda/lib/prim

FROM catthehacker/ubuntu:act-22.04

ENV DEBIAN_FRONTEND=noninteractive

# Runtime deps for act workflows + Agda tooling.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ghc \
        libffi-dev \
        libgmp-dev \
        libncurses-dev \
        zlib1g-dev \
        ca-certificates \
        git \
        pandoc \
        agda-stdlib \
    && rm -rf /var/lib/apt/lists/*

COPY --from=agda-builder /opt/agda/bin /usr/local/bin
COPY --from=agda-builder /opt/agda/lib/prim /usr/share/agda/lib/prim

# Create runner user matching typical host UID/GID (1000:1000)
# This prevents root-owned files in mounted workspace
RUN groupadd -g 1000 runner \
    && useradd -m -u 1000 -g 1000 -s /bin/bash runner

# Configure Agda library defaults and record prim path for consistency with CI.
ENV AGDA_STDLIB=/usr/share/agda-stdlib

ENV AGDA_EXEC_OPTIONS=--include-path=/usr/share/agda/lib/prim

# Configure Agda for both root and runner users
RUN for home in /root /home/runner; do \
      mkdir -p "$home/.agda"; \
      echo "$AGDA_STDLIB/standard-library.agda-lib" > "$home/.agda/libraries"; \
      echo "standard-library" > "$home/.agda/defaults"; \
    done \
    && chown -R runner:runner /home/runner

# Switch to runner user by default
USER runner
WORKDIR /home/runner

# Keep image lean: no node/python preinstalls; actions/setup-* will fetch versions.
