#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"
SOURCEMOD_VERSION="${SOURCEMOD_VERSION:-1.12}"

cd "$ROOT_DIR"
make deps-smx PYTHON="$PYTHON_BIN" SOURCEMOD_VERSION="$SOURCEMOD_VERSION" SMX_PLATFORM=linux
make build-smx PYTHON="$PYTHON_BIN" SPCOMP="deps/sourcemod-linux/addons/sourcemod/scripting/spcomp"
make package-smx PYTHON="$PYTHON_BIN"
"$PYTHON_BIN" ./scripts/stage-artifact.py . ./.build/package-smx ./deps/build-smx-compile.log
