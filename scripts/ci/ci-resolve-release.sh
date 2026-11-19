#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TAG_NAME="${1:-${GITHUB_REF_NAME:-}}"

if [[ -z "$TAG_NAME" ]]; then
  echo "Release tag is required." >&2
  exit 1
fi

case "$TAG_NAME" in
  sourcemod/v*)
    component="sourcemod"
    version="${TAG_NAME#sourcemod/v}"
    basename="l4d2-commsuite-${version}"
    release_name="SourceMod v${version}"
    ;;
  *)
    echo "Unsupported release tag '$TAG_NAME'. Use sourcemod/vX.Y.Z." >&2
    exit 1
    ;;
esac

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$ ]]; then
  echo "Tag version '$version' is not valid SemVer." >&2
  exit 1
fi

changelog="${RELEASE_CHANGELOG:-$ROOT_DIR/CHANGELOG.md}"
expected_version="$(python3 - "$changelog" <<'PYTHON'
from pathlib import Path
import re
import sys

changelog = Path(sys.argv[1]).read_text(encoding="utf-8")
heading = re.search(
    r"^## +\[?([0-9]+\.[0-9]+\.[0-9]+(?:[-.][0-9A-Za-z.-]+)?)\]?(?:\s|$)",
    changelog,
    flags=re.MULTILINE,
)
if not heading:
    raise SystemExit("No versioned release heading found in the changelog.")
print(heading.group(1))
PYTHON
)"

if [[ "$version" != "$expected_version" ]]; then
  echo "Tag version '$version' does not match bundle version in the changelog '$expected_version'." >&2
  exit 1
fi

prerelease="false"
if [[ "$version" == *-* ]]; then
  prerelease="true"
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "component=$component"
    echo "version=$version"
    echo "basename=$basename"
    echo "release_name=$release_name"
    echo "prerelease=$prerelease"
  } >> "$GITHUB_OUTPUT"
else
  cat <<EOF
component=$component
version=$version
basename=$basename
release_name=$release_name
prerelease=$prerelease
EOF
fi
