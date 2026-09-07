#!/usr/bin/env python3
"""Focused guard for the bounded l4d2_chatlog export API."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"Chat export contract failed: {message}")


plugin = read("addons/sourcemod/scripting/l4d2_chatlog.sp")
include = read("addons/sourcemod/scripting/include/l4d2_chatlog.inc")
manifest = json.loads(read("plugin-package-map.json"))

require('#define L4D2_CHATLOG_VERSION "0.4.1"' in plugin, "plugin version missing")
require("Version: 0.4.1" in include, "public include version comment missing")
require('RegPluginLibrary(L4D2_CHATLOG_LIBRARY)' in plugin, "library registration missing")
for native in ("L4D2ChatLog_GetActiveFile", "L4D2ChatLog_CreateSnapshot"):
    require(native in include and f'CreateNative("{native}"' in plugin, f"native missing: {native}")
require('#define L4D2_CHATLOG_EXPORT_ROOT "data/l4d2_chatlog/exports"' in plugin, "fixed root missing")
require('#define L4D2_CHATLOG_EXPORT_MAX_BYTES 8388608' in plugin, "8 MiB bound missing")
require('#define L4D2_CHATLOG_EXPORT_MAX_FILES 32' in plugin, "file-count bound missing")
require('#define L4D2_CHATLOG_EXPORT_MAX_AGE 86400' in plugin, "age bound missing")
require("ChatLog_IsCanonicalRequestId" in plugin, "closed UUID grammar missing")
require('"chatlog_%s.log"' in plugin, "snapshot name is not derived from request id")
snapshot_surface = plugin[plugin.index("public int Native_L4D2ChatLogCreateSnapshot"):
                          plugin.index("bool ChatLog_IsCanonicalRequestId")]
require("server_id" not in snapshot_surface and "ndjson" not in snapshot_surface.lower(),
        "flat legacy ABI must not fabricate server directories or NDJSON")
require("RenameFile(destination, temporary)" in plugin, "atomic finalization missing")
require("FileSize(sourcePath) == expectedSize" in plugin, "stable-source check missing")
require("L4D2_CHATLOG_EXPORT_SETGID 0x0400" in plugin, "POSIX setgid bit missing")
require("L4D2_CHATLOG_EXPORT_DIRECTORY_MODE" in plugin, "2770 directory mode missing")
require("L4D2_CHATLOG_EXPORT_FILE_MODE" in plugin, "0660 file mode missing")
require("SetFilePermissions(temporary, L4D2_CHATLOG_EXPORT_FILE_MODE)" in plugin,
        "temporary mode is not set before rename")
require(plugin.count("SetFilePermissions(destination, L4D2_CHATLOG_EXPORT_FILE_MODE)") == 2,
        "new and reused snapshots must reapply 0660")
require("GetFilePermissions(exportRoot, exportMode)" in plugin,
        "pre-provisioned setgid root is not validated")
require("createdExportRoot && !SetFilePermissions(exportRoot" in plugin,
        "existing group-owned root may be chmodded by SRCDS")
export_flow = plugin[plugin.index("public int Native_L4D2ChatLogCreateSnapshot"):
                     plugin.index("bool ChatLog_CopyStableFile")]
require("384" not in export_flow and "448" not in export_flow,
        "legacy 0600/0700 numeric mode remains in export flow")
mode_definitions = "\n".join(
    line for line in plugin.splitlines()
    if "L4D2_CHATLOG_EXPORT_DIRECTORY_MODE" in line
    or "L4D2_CHATLOG_EXPORT_FILE_MODE" in line
)
require("FPERM_O_" not in mode_definitions, "export modes grant world access")
require("chown" not in plugin.lower(), "plugin must not invent or change group ownership")
require("#include <steamworks>" not in plugin.lower()
        and "SteamWorks_CreateHTTPRequest" not in plugin,
        "CommSuite export must not transport HTTP")
require("l4d2_chatlog.inc" in manifest["artifact"]["addons"]["sourcemod"]["scripting"]["include"]["files"],
        "public include missing from artifact")

print("L4D2 ChatLog export contract: PASS")
