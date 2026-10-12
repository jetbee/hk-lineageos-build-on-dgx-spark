#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Make a set to use as a prebuilt kernel (Image.gz-dtb, config, headers, build info, sha256).
# usage: package-kernel.sh <kernel-src> [out-dir]   (output goes under $PACKAGE_DIR, default ~/kernel-package)
set -euo pipefail
K=$(realpath "$1"); O=${2:-out-clang}
H=$(git -C "$K" rev-parse --short=12 HEAD)
D=${PACKAGE_DIR:-$HOME/kernel-package}/kernel-$(date +%Y%m%d)-$H
rm -rf "$D"; mkdir -p "$D"
make -C "$K" O=$O ARCH=arm64 LLVM=1 LLVM_IAS=1 CC=clang INSTALL_HDR_PATH="$D/kernel-headers" headers_install >/dev/null
cp "$K/$O/arch/arm64/boot/Image.gz-dtb" "$K/$O/.config" "$D/"
mv "$D/.config" "$D/config"
find "$K/$O" -name '*.ko' -exec cp {} "$D/" \; 2>/dev/null || true
{
  echo "commit: $(git -C "$K" rev-parse HEAD) ($(git -C "$K" rev-parse --abbrev-ref HEAD))"
  echo "dirty: $(git -C "$K" status --porcelain | grep -v '^??' | wc -l) files"
  echo "release: $(cat "$K/$O/include/config/kernel.release")"
  grep LINUX_COMPILER "$K/$O/include/generated/compile.h" | cut -d'"' -f2 | sed 's/^/compiler: /'
  echo "host: $(uname -m)  built: $(date -Is)"
} > "$D/BUILD_INFO.txt"
(cd "$D" && find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
echo "$D"; du -sh "$D"
