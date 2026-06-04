#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"
RELEASE_BASENAME="${RELEASE_BASENAME:-l4d2-commsuite-local}"

cd "$ROOT_DIR"
make release PYTHON="$PYTHON_BIN" RELEASE_BASENAME="$RELEASE_BASENAME"
