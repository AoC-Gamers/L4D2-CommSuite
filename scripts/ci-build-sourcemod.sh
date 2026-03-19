#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${RUNNER_TEMP:-$ROOT_DIR/.tmp}/sourcemod-build"
DIST_DIR="$ROOT_DIR/dist/sourcemod"
ARTIFACT_DIR="$DIST_DIR/artifact"
SOURCEMOD_ARCHIVE_URL="${SOURCEMOD_ARCHIVE_URL:?SOURCEMOD_ARCHIVE_URL is required}"

rm -rf "$WORK_DIR" "$DIST_DIR"
mkdir -p "$WORK_DIR" "$ARTIFACT_DIR"

echo "Downloading SourceMod compiler package..."
curl -fsSL "$SOURCEMOD_ARCHIVE_URL" -o "$WORK_DIR/sourcemod.tar.gz"
tar -xzf "$WORK_DIR/sourcemod.tar.gz" -C "$WORK_DIR"

SOURCEMOD_DIR="$WORK_DIR"
SPCOMP_BIN="$SOURCEMOD_DIR/addons/sourcemod/scripting/spcomp"
SOURCEMOD_INCLUDE_DIR="$SOURCEMOD_DIR/addons/sourcemod/scripting/include"
LOCAL_INCLUDE_DIR="$ROOT_DIR/addons/sourcemod/scripting/include"
PACKAGE_SM_DIR="$ARTIFACT_DIR/addons/sourcemod"
PACKAGE_PLUGIN_DIR="$PACKAGE_SM_DIR/plugins/l4d2_commsuite"
COMPILE_LOG="$ARTIFACT_DIR/compile.log"

mkdir -p "$PACKAGE_PLUGIN_DIR"
: > "$COMPILE_LOG"

compile_plugin() {
  local source_file="$1"
  local output_file="$2"

  echo "Compiling $(basename "$source_file")..."
  "$SPCOMP_BIN" \
    "$source_file" \
    -i"$LOCAL_INCLUDE_DIR" \
    -i"$SOURCEMOD_INCLUDE_DIR" \
    -o"$output_file" \
    2>&1 | tee -a "$COMPILE_LOG"
}

compile_plugin "$ROOT_DIR/addons/sourcemod/scripting/l4d2_commcore.sp" "$PACKAGE_PLUGIN_DIR/l4d2_commcore.smx"
compile_plugin "$ROOT_DIR/addons/sourcemod/scripting/l4d2_commguard.sp" "$PACKAGE_PLUGIN_DIR/l4d2_commguard.smx"
compile_plugin "$ROOT_DIR/addons/sourcemod/scripting/l4d2_commrelay.sp" "$PACKAGE_PLUGIN_DIR/l4d2_commrelay.smx"
compile_plugin "$ROOT_DIR/addons/sourcemod/scripting/l4d2_chatnoise.sp" "$PACKAGE_PLUGIN_DIR/l4d2_chatnoise.smx"
compile_plugin "$ROOT_DIR/addons/sourcemod/scripting/l4d2_chatlog.sp" "$PACKAGE_PLUGIN_DIR/l4d2_chatlog.smx"

for plugin in \
  l4d2_commcore.smx \
  l4d2_commguard.smx \
  l4d2_commrelay.smx \
  l4d2_chatnoise.smx \
  l4d2_chatlog.smx
do
  if [[ ! -f "$PACKAGE_PLUGIN_DIR/$plugin" ]]; then
    echo "Compiled plugin was not generated: $plugin" >&2
    exit 1
  fi
done

PACKAGE_SCRIPTING_DIR="$PACKAGE_SM_DIR/scripting"
PACKAGE_INCLUDE_DIR="$PACKAGE_SCRIPTING_DIR/include"

mkdir -p "$PACKAGE_SCRIPTING_DIR" "$PACKAGE_INCLUDE_DIR" "$PACKAGE_SM_DIR/configs"

cp "$ROOT_DIR/addons/sourcemod/scripting/l4d2_commcore.sp" "$PACKAGE_SCRIPTING_DIR/"
cp "$ROOT_DIR/addons/sourcemod/scripting/l4d2_commguard.sp" "$PACKAGE_SCRIPTING_DIR/"
cp "$ROOT_DIR/addons/sourcemod/scripting/l4d2_commrelay.sp" "$PACKAGE_SCRIPTING_DIR/"
cp "$ROOT_DIR/addons/sourcemod/scripting/l4d2_chatnoise.sp" "$PACKAGE_SCRIPTING_DIR/"
cp "$ROOT_DIR/addons/sourcemod/scripting/l4d2_chatlog.sp" "$PACKAGE_SCRIPTING_DIR/"

cp -R "$ROOT_DIR/addons/sourcemod/scripting/l4d2_commcore" "$PACKAGE_SCRIPTING_DIR/"

cp "$ROOT_DIR/addons/sourcemod/scripting/include/l4d2_commcore.inc" "$PACKAGE_INCLUDE_DIR/"
cp "$ROOT_DIR/addons/sourcemod/scripting/include/l4d2_commguard.inc" "$PACKAGE_INCLUDE_DIR/"
cp "$ROOT_DIR/addons/sourcemod/scripting/include/l4d2_commrelay.inc" "$PACKAGE_INCLUDE_DIR/"
cp "$ROOT_DIR/addons/sourcemod/scripting/include/l4d2_commsuite_shared.inc" "$PACKAGE_INCLUDE_DIR/"

cp -R "$ROOT_DIR/addons/sourcemod/configs/sql-init-commsuite" "$PACKAGE_SM_DIR/configs/"

echo "SourceMod artifacts generated in $ARTIFACT_DIR"
