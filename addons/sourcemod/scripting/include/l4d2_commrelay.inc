/**
 * L4D2 CommRelay
 * Version: 0.3.0
 *
 * Unified chat and voice relay runtime for L4D2 CommSuite.
 */

#if defined _l4d2_commrelay_included
	#endinput
#endif
#define _l4d2_commrelay_included

#define L4D2_COMMRELAY_LIBRARY "l4d2_commrelay"
#define L4D2_COMMRELAY_VERSION "0.3.0"

/**
 * Returns true when spectator voice relay is enabled locally for the client.
 *
 * @param client        Client index.
 * @return              True if spectator voice relay is enabled.
 */
native bool L4D2CommRelay_IsClientVoiceEnabled(int client);

/**
 * Updates the spectator voice relay preference for a client.
 *
 * @param client        Client index.
 * @param enabled       True to enable relay, false to disable.
 * @param saveCookie    True to persist the preference in cookies.
 * @return              True if the request was accepted.
 */
native bool L4D2CommRelay_SetClientVoiceEnabled(int client, bool enabled, bool saveCookie = true);

public SharedPlugin __pl_l4d2_commrelay =
{
	name = L4D2_COMMRELAY_LIBRARY,
	file = "l4d2_commrelay.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_commrelay_SetNTVOptional()
{
	MarkNativeAsOptional("L4D2CommRelay_IsClientVoiceEnabled");
	MarkNativeAsOptional("L4D2CommRelay_SetClientVoiceEnabled");
}
#endif
