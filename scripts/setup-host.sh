#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Install the packages the builds need on a DGX Spark (Ubuntu 24.04, aarch64).
# imagemagick is used by the whole-Android build (mogrify for the boot animation).
set -euo pipefail
[ "$(uname -m)" = aarch64 ] || { echo "run this on an aarch64 host" >&2; exit 1; }
sudo apt-get update
sudo apt-get install -y \
  git make gcc bc bison flex m4 cpio zip unzip rsync python3 \
  clang lld llvm lz4 device-tree-compiler libssl-dev libelf-dev ccache \
  imagemagick python3-pil
