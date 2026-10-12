#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Build LineageOS's sdm660 kernel with the host clang (native aarch64).
#
# usage: build-kernel.sh <kernel-src> <device-fragment> [out-dir]
#   example: build-kernel.sh ~/src/android_kernel_asus_sdm660 X00TD
# device-fragment is <name> of arch/arm64/configs/vendor/<name>.config.
set -euo pipefail
SRC=$(realpath "$1"); DEV=$2; O=${3:-out-$DEV}
CFG="vendor/sdm660-perf_defconfig vendor/common.config vendor/debugfs.config vendor/$DEV.config"
M=(make -C "$SRC" O="$O" ARCH=arm64 LLVM=1 LLVM_IAS=1 CC=clang)
"${M[@]}" $CFG >/dev/null
start=$(date +%s)
"${M[@]}" -j"$(nproc)" 2>&1 | tee "$SRC/$O.log" | grep -E ': (error|warning):' || true
[ -f "$SRC/$O/arch/arm64/boot/Image.gz-dtb" ] || { echo "build failed: $SRC/$O.log" >&2; exit 1; }
echo "OK $(( $(date +%s) - start ))s: $SRC/$O/arch/arm64/boot/Image.gz-dtb"
cat "$SRC/$O/include/config/kernel.release"
