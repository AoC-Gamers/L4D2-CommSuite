#if defined _bansystem_comm_included
	#endinput
#endif
#define _bansystem_comm_included

enum eBSCommType
{
	kBSCommType_None = 0,
	kBSCommType_Mic = 1,
	kBSCommType_Chat = 2,
	kBSCommType_All = 3
}

/**
 * Queues a communication ban mutation using an already resolved accountid.
 *
 * The mutation itself is asynchronous; this native only reports whether the module accepted the request.
 *
 * @param iAdmin        Admin client index, or 0 for server console.
 * @param iAccountId    Internal Steam account id to punish.
 * @param iCommType     Communication type to apply.
 * @param iLength       Ban length in minutes. 0 means permanent.
 * @param szReason      Ban reason.
 * @param szContext     Optional ban context.
 * @param consoleName   Optional console/plugin issuer for iAdmin=0. Empty means Console.
 * @return              True only after Core returned a positive queued request id.
 */
native bool BSComm_AddBanByAccountId(int iAdmin, int iAccountId, eBSCommType iCommType, int iLength = 0, const char[] szReason = "", const char[] szContext = "", const char[] consoleName = "");

/**
 * Queues a communication unban mutation using an already resolved accountid.
 *
 * The mutation itself is asynchronous; this native only reports whether the module accepted the request.
 *
 * @param iAdmin        Admin client index, or 0 for server console.
 * @param iAccountId    Internal Steam account id to unban.
 * @return              True only after Core returned a positive queued request id.
 */
native bool BSComm_RemoveBanByAccountId(int iAdmin, int iAccountId);

/**
 * Returns true when the connected client currently has resolved communication ban state loaded.
 *
 * @param iClient       Client index.
 * Resolved state remains available when an optional executor is absent.
 * Use BSComm_IsClientRestrictionEffective to report effective enforcement.
 *
 * @return              True if the client has an active resolved communication ban.
 */
native bool BSComm_IsClientBanned(int iClient);

/** Returns the active resolved sanction type, or None when absent or expired. */
native eBSCommType BSComm_GetResolvedCommType(int iClient);

/**
 * Returns whether all dimensions of an active sanction are enforced locally.
 * Chat requires operational CommGuard/CommCore or BaseComm; microphone uses
 * BaseComm or the engine mute flag. This never queries CommGuard block natives.
 */
native bool BSComm_IsClientRestrictionEffective(int iClient);

/**
 * Requests a player-facing detailed status print for an already resolved accountid.
 *
 * The detail is read from the connected client's resolved in-memory state and
 * printed to the target client's console.
 *
 * @param iClient       Connected client that will receive the console output.
 * @param iAccountId    Internal Steam account id to inspect.
 * @return              True if the request was accepted by the module.
 */
native bool BSComm_PrintStatusByAccountId(int iClient, int iAccountId);

/**
 * Fired when the resolved communication state changes for a connected client.
 *
 * @param iClient       Client index.
 * @param bBlocked      True when an active resolved sanction exists, independent of executor availability.
 * @param eCommType     Resolved communication type, or `kBSCommType_None` when none.
 */
forward void BSComm_OnClientCommStateChanged(int iClient, bool bBlocked, eBSCommType eCommType);

public SharedPlugin __pl_bansystem_comm =
{
	name = "bansystem_comm",
	file = "bansystem_comm.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_bansystem_comm_SetNTVOptional()
{
	MarkNativeAsOptional("BSComm_AddBanByAccountId");
	MarkNativeAsOptional("BSComm_RemoveBanByAccountId");
	MarkNativeAsOptional("BSComm_IsClientBanned");
	MarkNativeAsOptional("BSComm_GetResolvedCommType");
	MarkNativeAsOptional("BSComm_IsClientRestrictionEffective");
	MarkNativeAsOptional("BSComm_PrintStatusByAccountId");
}
#endif
