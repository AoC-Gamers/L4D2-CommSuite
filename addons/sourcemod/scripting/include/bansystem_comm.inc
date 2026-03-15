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
 * @return              True if the request was accepted by the module.
 */
native bool BSComm_AddBanByAccountId(int iAdmin, int iAccountId, eBSCommType iCommType, int iLength = 0, const char[] szReason = "", const char[] szContext = "");

/**
 * Queues a communication unban mutation using an already resolved accountid.
 *
 * The mutation itself is asynchronous; this native only reports whether the module accepted the request.
 *
 * @param iAdmin        Admin client index, or 0 for server console.
 * @param iAccountId    Internal Steam account id to unban.
 * @return              True if the request was accepted by the module.
 */
native bool BSComm_RemoveBanByAccountId(int iAdmin, int iAccountId);

/**
 * Returns true when the module has resolved communication detail for a connected client.
 *
 * @param iClient       Client index.
 * @return              True if communication detail is resolved for the client.
 */
native bool BSComm_HasResolvedDetail(int iClient);

/**
 * Returns true when the connected client currently has resolved communication ban state loaded.
 *
 * @param iClient       Client index.
 * @return              True if the client has an active resolved communication ban.
 */
native bool BSComm_IsClientBanned(int iClient);

/**
 * Returns the resolved communication type cached for a connected client.
 *
 * @param iClient       Client index.
 * @return              Resolved communication type, or `kBSCommType_None` when none.
 */
native eBSCommType BSComm_GetResolvedCommType(int iClient);

public SharedPlugin __pl_bansystem_comm =
{
	name = "bansystem_comm",
	file = "bansystem_comm.smx",
	#if defined REQUIRE_PLUGIN
	required = 1
	#else
	required = 0
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_bansystem_comm_SetNTVOptional()
{
	MarkNativeAsOptional("BSComm_AddBanByAccountId");
	MarkNativeAsOptional("BSComm_RemoveBanByAccountId");
	MarkNativeAsOptional("BSComm_HasResolvedDetail");
	MarkNativeAsOptional("BSComm_IsClientBanned");
	MarkNativeAsOptional("BSComm_GetResolvedCommType");
}
#endif
