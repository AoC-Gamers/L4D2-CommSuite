/**
 * L4D2 ChatLog
 * Version: 0.4.1
 *
 * Minimal export API for the active functional chat log.
 */

#if defined _l4d2_chatlog_included
	#endinput
#endif
#define _l4d2_chatlog_included

#define L4D2_CHATLOG_LIBRARY "l4d2_chatlog"
#define L4D2_CHATLOG_PLUGIN "l4d2_chatlog.smx"
#define L4D2_CHATLOG_API_VERSION 1
#define L4D2_CHATLOG_REQUEST_ID_LENGTH 36

/**
 * Copies the current logical chat file path into the caller buffer.
 *
 * The result is relative to Path_SM and always belongs to logs/chats/. It is
 * informational only; callers cannot select a path through this native.
 */
native bool L4D2ChatLog_GetActiveFile(char[] path, int maxLength);

/**
 * Creates an immutable copy of the active daily log in the fixed export root.
 *
 * requestId must be a canonical lowercase UUID. snapshotName receives only a
 * logical file name, never a path or file contents. Repeating the request is
 * successful only while the existing snapshot still matches the active file.
 * The fixed export root must be a setgid 2770 directory prepared by deployment;
 * snapshots are finalized as 0660 and inherit that directory's group.
 */
native bool L4D2ChatLog_CreateSnapshot(
	const char[] requestId,
	char[] snapshotName,
	int maxLength
);

public SharedPlugin __pl_l4d2_chatlog =
{
	name = L4D2_CHATLOG_LIBRARY,
	file = L4D2_CHATLOG_PLUGIN,
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_chatlog_SetNTVOptional()
{
	MarkNativeAsOptional("L4D2ChatLog_GetActiveFile");
	MarkNativeAsOptional("L4D2ChatLog_CreateSnapshot");
}
#endif
