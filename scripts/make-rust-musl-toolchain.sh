#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Rust 1.93.1 for an aarch64 build host, in the layout lineage-24.0's Soong expects
# (prebuilts/rust-toolchain/linux-arm64/1.93.1).
#
# Why the musl rustc: Soong builds proc-macro crates as musl shared objects, and a
# glibc rustc cannot load them. The official aarch64-unknown-linux-musl rustc works,
# but the host has no /lib/ld-musl-aarch64.so.1, so bin/rustc is a wrapper that starts
# rustc.bin through the musl loader that the build-tools already ship (libc_musl.so).
#   usage: make-rust-musl-toolchain.sh <dir with the tarballs> <lineage tree> <output dir>
set -euo pipefail
TARS=$1 TREE=$2 OUT=$3
V=1.93.1
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
tar -C "$work" -xf "$TARS/rust-$V-aarch64-unknown-linux-musl.tar.xz"
(cd "$work"/rust-$V-aarch64-unknown-linux-musl &&
 ./install.sh --prefix="$OUT" --components=rustc,rust-std-aarch64-unknown-linux-musl --disable-ldconfig >/dev/null)
mv "$OUT/bin/rustc" "$OUT/bin/rustc.bin"
# the musl loader (libc.so) and an unwinder named libgcc_s.so.1 for librustc_driver
cp "$TREE/prebuilts/build-tools/linux-arm64/lib64/libc_musl.so" "$OUT/lib/libc.so"
cp "$TREE/prebuilts/clang/host/linux-arm64/clang-stable/lib/aarch64-unknown-linux-musl/libunwind.so" "$OUT/lib/libgcc_s.so.1"
# the standard library sources are architecture independent: reuse the x86 toolchain's
ln -sfn "$(readlink -f "$TREE/prebuilts/rust-toolchain/linux-x86/$V/lib/rustlib/src")" "$OUT/lib/rustlib/src"
cat > "$OUT/bin/rustc" <<'EOS'
#!/bin/sh
# rustc for an aarch64 musl host, started through musl's own loader
d=$(dirname "$(readlink -f "$0")")
case " $* " in *" --sysroot "*|*" --sysroot="*) ;; *) set -- --sysroot "$d/.." "$@";; esac
exec "$d/../lib/libc.so" --library-path "$d/../lib" "$d/rustc.bin" "$@"
EOS
chmod +x "$OUT/bin/rustc"
"$OUT/bin/rustc" --version
