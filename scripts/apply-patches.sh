#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Apply patches/ to a lineage-24.0 tree with git am (one directory per project).
#   usage: apply-patches.sh <lineage tree> [patches dir]
# A patches/ directory name is the project path with / replaced by _ . Projects whose names
# contain an underscore or a minus are listed in the table below.
set -euo pipefail
T=$(readlink -f "$1"); P=$(readlink -f "${2:-$(dirname "$0")/../patches}")
declare -A MAP=(
  [bionic]=bionic [build_make]=build/make [build_soong]=build/soong
  [external_rust_android-crates-io]=external/rust/android-crates-io
  [frameworks_libs_binary_translation]=frameworks/libs/binary_translation
  [prebuilts_build-tools]=prebuilts/build-tools
  [prebuilts_clang_host_linux-x86]=prebuilts/clang/host/linux-x86
  [prebuilts_jdk_jdk21]=prebuilts/jdk/jdk21
  [prebuilts_rust-toolchain_linux-x86]=prebuilts/rust-toolchain/linux-x86
  [prebuilts_tools-lineage]=prebuilts/tools-lineage
  [system_librustutils]=system/librustutils [system_sepolicy]=system/sepolicy
  [vendor_lineage]=vendor/lineage )
for d in "$P"/*/; do
  n=$(basename "$d"); proj=${MAP[$n]:?unknown patch directory $n}
  echo "== $proj"
  git -C "$T/$proj" am --quiet "$d"*.patch
done
