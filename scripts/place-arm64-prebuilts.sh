#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Make the arm64 prebuilts visible to a lineage-24.0 tree, using symlinks (nothing in
# the tree's git projects changes).
#   usage: place-arm64-prebuilts.sh <lineage tree> <arm64-prebuilts dir> <out dir>
# <arm64-prebuilts dir> holds: clang/clang-r584948b, go, jdk21 (extracted Temurin 21),
# rust-toolchain-1.93.1-musl (see make-rust-musl-toolchain.sh). See fetch-arm64-prebuilts.sh.
#
# LineageOS selects clang-r596125 (vendor/lineage release flag); Google publishes no
# arm64 build of it, so that name points at r584948b until a real one exists. To switch,
# fetch the real clang and re-point clang-r596125 / clang-stable here.
set -euo pipefail
T=$(readlink -f "$1") P=$(readlink -f "$2") OUT=$3
ln_() { mkdir -p "$(dirname "$2")"; ln -sfn "$1" "$2"; }
c=$T/prebuilts/clang/host/linux-arm64
ln_ "$P/clang/clang-r584948b" "$c/clang-r584948b"
for n in clang-r584948 clang-r596125 clang-stable; do ln_ clang-r584948b "$c/$n"; done
# llvm build tools run from the x86 clang directory in the tree; give them an arm64 twin
for n in clang-r596125-arm64 clang-r584948-arm64; do ln_ "$P/clang/clang-r584948b" "$T/prebuilts/clang/host/linux-x86/$n"; done
ln_ "$P/go" "$T/prebuilts/go/linux-arm64"
ln_ "$P/jdk21" "$T/prebuilts/jdk/jdk21/linux-arm64"
ln_ linux-x86 "$T/prebuilts/jdk/jdk8/linux-arm64"       # only the jars are used
r=$T/prebuilts/rust-toolchain/linux-arm64
mkdir -p "$r"
ln_ "$P/rust-toolchain-1.93.1-musl" "$r/1.93.1"
mkdir -p "$r/stable" && cp -a "$T/prebuilts/rust-toolchain/linux-x86/stable/." "$r/stable/"
# Soong rejects an absolute OUT_DIR in a few places: use out/ and point it elsewhere
[ -e "$T/out" ] || ln -s "$OUT" "$T/out"
