#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Fetch the prebuilts needed to build lineage-24.0 on an aarch64 host.
# They go to $DEST (default ~/arm64-prebuilts); where each came from is recorded in $DEST/SOURCES.txt.
#
# The versions follow what lineage-24.0's build/soong asks for:
#   clang-r584948 (r584948b is the arm64 build of the same line), Go 1.25.4, Rust 1.93.1, JDK 21
set -euo pipefail
DEST=${DEST:-$HOME/arm64-prebuilts}
AOSP=https://android.googlesource.com
CLANG_BRANCH=mirror-goog-main-prebuilts
CLANG_VER=clang-r584948b
GO_BRANCH=mirror-goog-llvm-r596125-release
RUST_VER=1.93.1
mkdir -p "$DEST"; cd "$DEST"
log() { echo "$*" | tee -a SOURCES.txt; }
: > SOURCES.txt
log "# fetched $(date -u +%FT%TZ) on $(uname -m)"

# 1. clang (Apache-2.0 with LLVM exception): fetch only the needed version, sparse
if [ ! -d clang/$CLANG_VER ]; then
	git clone -q --depth=1 --filter=blob:none --sparse -b $CLANG_BRANCH \
		$AOSP/platform/prebuilts/clang/host/linux-arm64 clang
	git -C clang sparse-checkout set $CLANG_VER
fi
log "clang  $AOSP/platform/prebuilts/clang/host/linux-arm64 $CLANG_BRANCH $(git -C clang rev-parse HEAD) $CLANG_VER"

# 2. Go（BSD-3-Clause）
[ -d go ] || git clone -q --depth=1 -b $GO_BRANCH $AOSP/platform/prebuilts/go/linux-arm64 go
log "go     $AOSP/platform/prebuilts/go/linux-arm64 $GO_BRANCH $(git -C go rev-parse HEAD) $(head -1 go/VERSION)"

# 3. Rust (Apache-2.0 / MIT): the official distribution; the host's glibc build and the musl std
fetch_rust() {
	local f=$1 url=https://static.rust-lang.org/dist/$1
	[ -f "$f" ] || curl -sfLO "$url"
	curl -sfL "$url.sha256" | awk '{print $1"  '"$f"'"}' | sha256sum -c --quiet
	log "rust   $url sha256=$(sha256sum "$f" | cut -d' ' -f1)"
}
fetch_rust rust-$RUST_VER-aarch64-unknown-linux-gnu.tar.xz
fetch_rust rust-std-$RUST_VER-aarch64-unknown-linux-musl.tar.xz

# 4. JDK 21 (GPL-2.0 with Classpath Exception): the latest Eclipse Temurin 21
api=https://api.adoptium.net/v3/assets/latest/21/hotspot?architecture=aarch64\&image_type=jdk\&os=linux\&vendor=eclipse
read -r JURL JSUM JNAME < <(curl -sfL "$api" | python3 -c '
import json, sys
p = json.load(sys.stdin)[0]["binary"]["package"]
print(p["link"], p["checksum"], p["name"])')
[ -f "$JNAME" ] || curl -sfL -o "$JNAME" "$JURL"
echo "$JSUM  $JNAME" | sha256sum -c --quiet
log "jdk    $JURL sha256=$JSUM"

du -sh clang go ./*.tar.* 2>/dev/null | tee -a SOURCES.txt
