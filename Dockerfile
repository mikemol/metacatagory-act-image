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
# Set HOME=/home/runner so cabal store is created as runner-owned, not root-owned
RUN mkdir -p /opt/agda/bin /home/runner

RUN --mount=type=cache,target=/home/runner/.cabal \
    --mount=type=cache,target=/home/runner/.cache \
    export HOME=/home/runner; \
    cabal update

RUN --mount=type=cache,target=/home/runner/.cabal \
    --mount=type=cache,target=/home/runner/.cache \
    export HOME=/home/runner; \
    cabal install alex happy

RUN --mount=type=cache,target=/home/runner/.cabal \
    --mount=type=cache,target=/home/runner/.cache \
    set -e; \
    export HOME=/home/runner; \
    cabal install Agda-${AGDA_VERSION} \
      --install-method=copy \
      --overwrite-policy=always \
      --installdir=/opt/agda/bin; \
    AGDA_DATA="$(PATH=/opt/agda/bin:$PATH agda --print-agda-data-dir)"; \
    mkdir -p /opt/agda/share; \
    if [ -d "$AGDA_DATA" ]; then cp -r "$AGDA_DATA"/* /opt/agda/share/; fi

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
COPY --from=agda-builder /opt/agda/share /usr/share/agda

# Create runner user matching typical host UID/GID (1000:1000)
# This prevents root-owned files in mounted workspace
RUN groupadd -g 1000 runner \
    && useradd -m -u 1000 -g 1000 -s /bin/bash runner

# Configure Agda library defaults and system paths (FHS-compliant)
ENV AGDA_STDLIB=/usr/share/agda-stdlib
ENV AGDA_DATA_DIR=/usr/share/agda

# Configure Agda for both root and runner users
# Ensure runner user owns Agda data directory
RUN for home in /root /home/runner; do \
      mkdir -p "$home/.agda"; \
      echo "$AGDA_STDLIB/standard-library.agda-lib" > "$home/.agda/libraries"; \
      echo "standard-library" > "$home/.agda/defaults"; \
    done \
    && chown -R runner:runner /home/runner /usr/share/agda

# Switch to runner user by default
USER runner
WORKDIR /home/runner

# Keep image lean: no node/python preinstalls; actions/setup-* will fetch versions.
