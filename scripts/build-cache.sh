#!/usr/bin/env bash
set -euo pipefail
docker buildx build \
  --build-arg CABAL_JOBS=2 \
  -t ghcr.io/mikemol/act-ubuntu-agda:latest \
  --cache-from type=registry,ref=ghcr.io/mikemol/act-ubuntu-agda:buildcache \
  --cache-to type=registry,ref=ghcr.io/mikemol/act-ubuntu-agda:buildcache,mode=max \
  --load .
