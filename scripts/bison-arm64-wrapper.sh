#!/bin/sh
# bison for an aarch64 build host. The binary expects to be installed as
# <prefix>/linux-x86/bin/bison and finds its data files relative to that, which
# does not hold for linux-arm64, so point it at the shared data directory.
d=$(cd "$(dirname "$0")" && pwd)
: "${BISON_PKGDATADIR:=$d/../../common/bison}"
export BISON_PKGDATADIR
exec "$d/bison.real" "$@"
