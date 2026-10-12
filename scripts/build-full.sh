#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Full LineageOS 24.0 build on an aarch64 host (a thin wrapper around build-images.sh).
#   usage: build-full.sh <lineage tree> <lunch target> <log file> [m targets, default: bacon]
set -euo pipefail
here=$(dirname "$0"); T=$1 TARGET=$2 LOG=$3; shift 3
exec "$here/build-images.sh" "$T" "$TARGET" "$LOG" "${@:-bacon}"
