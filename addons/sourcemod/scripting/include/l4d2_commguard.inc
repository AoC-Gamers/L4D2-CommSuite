/**
 * L4D2 CommGuard
 * Version: 0.1.0
 *
 * Unified communication guard runtime for L4D2 CommSuite.
 * Provides chat and voice guard APIs backed by a single runtime.
 */

#if defined _l4d2_commguard_included
	#endinput
#endif
#define _l4d2_commguard_included

#include <l4d2_commcore>

#define L4D2_COMMGUARD_LIBRARY "l4d2_commguard"
#define L4D2_COMMGUARD_VERSION "0.1.0"

/**
 * Punishment providers recognized by CommGuard.
 *
 * Values are bit flags so they can also represent a loaded-provider mask.
 */
enum L4D2CommGuardProvider
{
	Provider_None = 0,
	Provider_BaseComm = 1,
	Provider_SourceComms = 2,
	Provider_BanSystemComm = 4
};

/**
 * Returns whether the client should be blocked from sending chat.
 *
 * @param client        Client index.
 * @param channel       Chat channel.
 * @param text          Optional chat text.
 * @return              True if chat should be blocked.
 */
native bool L4D2CommGuard_IsClientChatBlocked(int client, L4D2CommChannel channel, const char[] text = "");

/**
 * Returns whether the client should be treated as voice-blocked.
 *
 * @param client        Client index.
 * @return              True if voice should be blocked for the client.
 */
native bool L4D2CommGuard_IsClientVoiceBlocked(int client);

/**
 * Returns a bitmask of punishment providers currently loaded by CommGuard.
 *
 * @return              Loaded provider bitmask using `L4D2CommGuardProvider` flags.
 */
native L4D2CommGuardProvider L4D2CommGuard_GetLoadedProviderMask();

/**
 * Returns the provider currently used by CommGuard.
 *
 * @return              Active provider enum value.
 */
native L4D2CommGuardProvider L4D2CommGuard_GetActiveProvider();

/**
 * Fired after built-in provider checks for chat.
 *
 * Returning Plugin_Handled blocks the chat call.
 *
 * @param client        Client index.
 * @param channel       Chat channel.
 * @param text          Chat text.
 * @return              Action result.
 */
forward Action L4D2CommGuard_OnChatBlockCheck(int client, L4D2CommChannel channel, const char[] text);

/**
 * Fired after built-in provider checks for voice.
 *
 * Returning Plugin_Handled marks the client as voice-blocked.
 *
 * @param client        Client index.
 * @return              Action result.
 */
forward Action L4D2CommGuard_OnVoiceBlockCheck(int client);

/**
 * Fired when the resolved voice-block state changes for a client.
 *
 * @param client        Client index.
 * @param blocked       True if voice is now blocked, false otherwise.
 */
forward void L4D2CommGuard_OnClientVoiceBlockChanged(int client, bool blocked);

public SharedPlugin __pl_l4d2_commguard =
{
	name = L4D2_COMMGUARD_LIBRARY,
	file = "l4d2_commguard.smx",
	#if defined REQUIRE_PLUGIN
	required = 1
	#else
	required = 0
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_commguard_SetNTVOptional()
{
	MarkNativeAsOptional("L4D2CommGuard_IsClientChatBlocked");
	MarkNativeAsOptional("L4D2CommGuard_IsClientVoiceBlocked");
	MarkNativeAsOptional("L4D2CommGuard_GetLoadedProviderMask");
	MarkNativeAsOptional("L4D2CommGuard_GetActiveProvider");
}
#endif
