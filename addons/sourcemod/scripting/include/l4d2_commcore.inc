/**
 * L4D2 CommCore
 * Version: 0.1.0-dev
 *
 * Public core API for centralized communication hooks in Left 4 Dead 2.
 * The current implementation covers chat input and chat-related noise.
 */

#if defined _l4d2_commcore_included
	#endinput
#endif
#define _l4d2_commcore_included

#include <left4dhooks_stocks>

#define L4D2_COMMCORE_LIBRARY "l4d2_commcore"
#define L4D2_COMMCORE_VERSION "0.1.0-dev"

enum L4D2CommChannel
{
	L4D2CommChannel_Public = 0,
	L4D2CommChannel_Team
};

/**
 * Returns whether the core finished its startup path.
 *
 * @return              True if the core is ready.
 */
native bool L4D2Comm_IsCoreReady();

/**
 * Fired before the game chat function continues.
 *
 * Returning Plugin_Handled blocks the game chat call.
 * Returning Plugin_Stop also blocks the post forward.
 *
 * @param client        Client index.
 * @param channel       Chat channel.
 * @param text          Chat text.
 * @return              Action result.
 */
forward Action L4D2Comm_OnChatMessage(int client, L4D2CommChannel channel, const char[] text);

/**
 * Fired after the game chat path continues.
 *
 * @param client        Client index.
 * @param channel       Chat channel.
 * @param text          Chat text.
 */
forward void L4D2Comm_OnChatMessage_Post(int client, L4D2CommChannel channel, const char[] text);

/**
 * Fired when the core intercepts the "server_cvar" event in pre mode.
 *
 * Returning Plugin_Handled blocks the event broadcast.
 *
 * @param cvarName      Changed cvar name.
 * @param cvarValue     New cvar value.
 * @return              Action result.
 */
forward Action L4D2Comm_OnServerCvarMessage(const char[] cvarName, const char[] cvarValue);

/**
 * Fired when the core intercepts the "player_connect" event in pre mode.
 *
 * Returning Plugin_Handled blocks the event broadcast.
 *
 * @param playerName    Connecting player name.
 * @return              Action result.
 */
forward Action L4D2Comm_OnPlayerConnectMessage(const char[] playerName);

/**
 * Fired when the core intercepts the "player_disconnect" event in pre mode.
 *
 * Returning Plugin_Handled blocks the event broadcast.
 *
 * @param playerName    Disconnecting player name.
 * @param reason        Disconnect reason.
 * @return              Action result.
 */
forward Action L4D2Comm_OnPlayerDisconnectMessage(const char[] playerName, const char[] reason);

/**
 * Fired when the core intercepts the "player_changename" event in pre mode.
 *
 * Returning Plugin_Handled blocks the event broadcast.
 *
 * @param oldName       Previous player name.
 * @param newName       New player name.
 * @return              Action result.
 */
forward Action L4D2Comm_OnPlayerNameChangeMessage(const char[] oldName, const char[] newName);

/**
 * Fired when the core intercepts the "player_team" event in pre mode.
 *
 * Returning Plugin_Handled blocks the event broadcast.
 *
 * @param playerName    Player name associated with the event.
 * @param team          Target team from the event payload.
 * @param disconnect    True if the event is part of a disconnect flow.
 * @return              Action result.
 */
forward Action L4D2Comm_OnPlayerTeamMessage(const char[] playerName, L4DTeam team, bool disconnect);

/**
 * Fired when the core intercepts the "TextMsg" usermessage.
 *
 * Returning Plugin_Handled blocks the usermessage.
 *
 * @param msgKey        Localized message token.
 * @param param1        First message parameter.
 * @param param2        Second message parameter.
 * @param param3        Third message parameter.
 * @param param4        Fourth message parameter.
 * @param firstTarget   First target client in the recipient list, or 0.
 * @param playersNum    Recipient count.
 * @param reliable      Whether the message is reliable.
 * @param init          Whether the message is an init message.
 * @return              Action result.
 */
forward Action L4D2Comm_OnTextMsgMessage(const char[] msgKey, const char[] param1, const char[] param2, const char[] param3, const char[] param4, int firstTarget, int playersNum, bool reliable, bool init);

/**
 * Fired when the core intercepts the "SayText2" usermessage.
 *
 * Returning Plugin_Handled blocks the usermessage.
 *
 * @param msgKey        Localized message token.
 * @param param1        First message parameter.
 * @param param2        Second message parameter.
 * @param param3        Third message parameter.
 * @param param4        Fourth message parameter.
 * @param firstTarget   First target client in the recipient list, or 0.
 * @param playersNum    Recipient count.
 * @param reliable      Whether the message is reliable.
 * @param init          Whether the message is an init message.
 * @return              Action result.
 */
forward Action L4D2Comm_OnSayText2Message(const char[] msgKey, const char[] param1, const char[] param2, const char[] param3, const char[] param4, int firstTarget, int playersNum, bool reliable, bool init);

#define L4D2ChatChannel L4D2CommChannel
#define L4D2ChatChannel_Public L4D2CommChannel_Public
#define L4D2ChatChannel_Team L4D2CommChannel_Team
#define L4D2CC_IsCoreReady L4D2Comm_IsCoreReady
#define L4D2CC_OnChatMessage L4D2Comm_OnChatMessage
#define L4D2CC_OnChatMessage_Post L4D2Comm_OnChatMessage_Post
#define L4D2CC_OnServerCvarMessage L4D2Comm_OnServerCvarMessage
#define L4D2CC_OnPlayerConnectMessage L4D2Comm_OnPlayerConnectMessage
#define L4D2CC_OnPlayerDisconnectMessage L4D2Comm_OnPlayerDisconnectMessage
#define L4D2CC_OnPlayerNameChangeMessage L4D2Comm_OnPlayerNameChangeMessage
#define L4D2CC_OnPlayerTeamMessage L4D2Comm_OnPlayerTeamMessage
#define L4D2CC_OnTextMsgMessage L4D2Comm_OnTextMsgMessage
#define L4D2CC_OnSayText2Message L4D2Comm_OnSayText2Message

public SharedPlugin __pl_l4d2_commcore =
{
	name = "l4d2_commcore",
	file = "l4d2_commcore.smx",
	#if defined REQUIRE_PLUGIN
	required = 1
	#else
	required = 0
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_commcore_SetNTVOptional()
{
	MarkNativeAsOptional("L4D2Comm_IsCoreReady");
	MarkNativeAsOptional("L4D2CC_IsCoreReady");
}
#endif
