#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Repeatable image builds on an aarch64 host: clean environment, automatic -j, and a guard
# against stale timestamps.
#   usage: build-images.sh <lineage tree> <lunch target> <log file> <m targets...>
#   env:   JOBS         number of jobs (default: auto, see below)
#          STALE_REPOS  space separated project directories (relative to the tree) that are
#                       copied in from elsewhere, e.g. "device/acme/foo vendor/acme/foo"
#          STATE_DIR    where the last built commit of each STALE_REPOS entry is kept
#                       (default ~/.cache/lineage-build)
#
# Why the stale-timestamp guard: when a project is updated with rsync -a (or any copy that
# keeps the modification times), a file edited before the previous build finished looks
# older than the previous outputs, ninja skips it, and the image silently keeps the old
# content. Before a build, every file that differs from the commit that was last built
# successfully is touched (all files, if there is no record).
#
# Why the automatic -j: memory is shared with other jobs on the machine. About 3 GB per job
# is a rule of thumb (not a measurement): JOBS = MemAvailable / 3 GB, between 2 and nproc.
set -uo pipefail
T=$(readlink -f "$1") TARGET=$2 LOG=$3; shift 3
STATE=${STATE_DIR:-$HOME/.cache/lineage-build}; mkdir -p "$STATE"
for r in ${STALE_REPOS:-}; do
  d=$T/$r; k=$STATE/$(echo "$r" | tr / _).last
  prev=$(cat "$k" 2>/dev/null || true)
  if [ -n "$prev" ] && git -C "$d" cat-file -e "$prev" 2>/dev/null; then
    git -C "$d" diff --name-only "$prev" HEAD | while read -r f; do [ -e "$d/$f" ] && touch "$d/$f"; done
  else
    find "$d" -path "$d/.git" -prune -o -type f -print0 | xargs -0 touch
  fi
done
if [ -z "${JOBS:-}" ]; then
  avail=$(awk '/MemAvailable/ {printf "%d", $2/1048576}' /proc/meminfo)
  JOBS=$((avail/3)); n=$(nproc)
  [ "$JOBS" -gt "$n" ] && JOBS=$n; [ "$JOBS" -lt 2 ] && JOBS=2
fi
echo "jobs: $JOBS" >&2
# env -i: shell aliases and functions (grep -> ugrep, ...) must not reach the build scripts
env -i HOME="$HOME" PATH=/usr/local/bin:/usr/bin:/bin bash --noprofile --norc -c '
cd "$0"
export OUT_DIR=out                # an absolute OUT_DIR stops Soong in a few places
export SOONG_NINJA=ninja          # siso is x86 only
export SKIP_ABI_CHECKS=true       # no arm64 header-abi-dumper
export SOONG_DISABLE_CLIPPY=true  # no arm64 clippy-driver
export THINLTO_USE_MLGO=false     # the arm64 clang has no MLGO model
source build/envsetup.sh >/dev/null 2>&1
lunch "$1" >/dev/null
log=$2; shift 2
m "$@" > "$log" 2>&1
echo "exit=$?" >> "$log"
' "$T" "$TARGET" "$LOG" -j"$JOBS" "$@"
grep -q '^exit=0' "$LOG" || { echo "BUILD FAILED, see $LOG" >&2; exit 3; }
for r in ${STALE_REPOS:-}; do git -C "$T/$r" rev-parse HEAD > "$STATE/$(echo "$r" | tr / _).last"; done
