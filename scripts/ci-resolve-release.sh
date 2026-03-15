#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG_NAME="${1:-${GITHUB_REF_NAME:-}}"

if [[ -z "$TAG_NAME" ]]; then
  echo "Release tag is required." >&2
  exit 1
fi

case "$TAG_NAME" in
  sourcemod/v*)
    component="sourcemod"
    version="${TAG_NAME#sourcemod/v}"
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

expected_version="$(python3 - "$ROOT_DIR" <<'PY'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
files = [
    root / "addons/sourcemod/scripting/include/l4d2_commcore.inc",
    root / "addons/sourcemod/scripting/include/l4d2_commguard.inc",
    root / "addons/sourcemod/scripting/include/l4d2_commrelay.inc",
    root / "addons/sourcemod/scripting/l4d2_chatnoise.sp",
    root / "addons/sourcemod/scripting/l4d2_chatlog.sp",
]

versions = []
pattern = re.compile(r'#define\s+\S+_VERSION\s+"([^"]+)"')

for path in files:
    text = path.read_text(encoding="utf-8")
    match = pattern.search(text)
    if not match:
        print(f"Missing version macro in {path}", file=sys.stderr)
        sys.exit(1)
    versions.append(match.group(1))

unique = sorted(set(versions))
if len(unique) != 1:
    print("Version mismatch across suite files: " + ", ".join(unique), file=sys.stderr)
    sys.exit(1)

print(unique[0])
PY
)"

if [[ -z "$expected_version" ]]; then
  echo "Could not resolve expected sourcemod version." >&2
  exit 1
fi

if [[ "$version" != "$expected_version" ]]; then
  echo "Tag version '$version' does not match declared sourcemod version '$expected_version'." >&2
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
    echo "release_name=$release_name"
    echo "prerelease=$prerelease"
  } >> "$GITHUB_OUTPUT"
else
  cat <<EOF
component=$component
version=$version
release_name=$release_name
prerelease=$prerelease
EOF
fi
