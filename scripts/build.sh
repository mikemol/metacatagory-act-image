#!/usr/bin/env bash
set -euo pipefail
docker build \
  --build-arg CABAL_JOBS=2 \
  -t ghcr.io/mikemol/act-ubuntu-agda:latest \
  .
