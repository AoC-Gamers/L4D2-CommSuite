#pragma semicolon 1
#pragma newdecls required

#include <clientprefs>
#include <console>
#include <colors>
#include <left4dhooks_stocks>
#include <sdktools_voice>
#include <sourcemod>

#include <l4d2_commcore>
#include <l4d2_commguard>
#include <l4d2_commrelay>
#include <l4d2_commsuite_shared>

enum RelayDebugMask
{
	Debug_General = 1,
	Debug_Chat = 2,
	Debug_Voice = 4
};

ConVar g_cvDebugMask = null;
ConVar g_cvChatEnabled = null;
ConVar g_cvChatSpecTeam = null;
ConVar g_cvChatSourceTVTeam = null;
ConVar g_cvVoiceEnabled = null;
ConVar g_cvVoiceDefaultEnabled = null;
ConVar g_cvVoiceSurvivor = null;
ConVar g_cvVoiceInfected = null;
ConVar g_cvLogMode = null;

Handle g_hCookieVoiceEnabled = INVALID_HANDLE;

bool g_bCoreAvailable = false;
bool g_bCommGuardAvailable = false;
bool g_bVoiceEnabledByClient[MAXPLAYERS + 1];
bool g_bCookiesCached[MAXPLAYERS + 1];
bool g_bPendingCookieSave[MAXPLAYERS + 1];
bool g_bVoiceRefreshQueued = false;
char g_sLogPath[PLATFORM_MAX_PATH];

public Plugin myinfo =
{
	name = "L4D2 CommRelay",
	author = "lechuga",
	description = "Unified chat and voice relay runtime for L4D2 CommSuite.",
	version = L4D2_COMMRELAY_VERSION,
	url = "https://github.com/AoC-Gamers/L4D2-CommSuite"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int errMax)
{
	RegPluginLibrary(L4D2_COMMRELAY_LIBRARY);
	CreateNative("L4D2CommRelay_IsClientVoiceEnabled", Native_IsVoiceEnabled);
	CreateNative("L4D2CommRelay_SetClientVoiceEnabled", Native_SetVoiceEnabled);
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_cvLogMode = L4D2CS_EnsureLogModeConVar();
	g_cvDebugMask = CreateConVar("l4d2_commrelay_debug_mask", "0", "Debug bitmask. 1=general 2=chat 4=voice (all=7).", FCVAR_NONE, true, 0.0, true, 7.0);
	g_cvChatEnabled = CreateConVar("l4d2_commrelay_chat_enabled", "1", "Enable chat relay handling.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvChatSpecTeam = CreateConVar("l4d2_commrelay_chat_spec_team", "0", "Relay survivor and infected team chat to spectators.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvChatSourceTVTeam = CreateConVar("l4d2_commrelay_chat_sourcetv_team", "0", "Relay team chat to SourceTV and replay clients.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvVoiceEnabled = CreateConVar("l4d2_commrelay_voice_enabled", "1", "Enable spectator voice relay handling.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvVoiceDefaultEnabled = CreateConVar("l4d2_commrelay_voice_default_enabled", "1", "Default spectator voice relay state for new users.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvVoiceSurvivor = CreateConVar("l4d2_commrelay_voice_survivor", "1", "Allow spectators to hear survivor voice chat.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvVoiceInfected = CreateConVar("l4d2_commrelay_voice_infected", "1", "Allow spectators to hear infected voice chat.", FCVAR_NONE, true, 0.0, true, 1.0);
	L4D2CS_BuildLogPath("l4d2_commrelay.log", g_sLogPath, sizeof(g_sLogPath));

	g_hCookieVoiceEnabled = RegClientCookie("l4d2_commrelay_voice_enabled", "L4D2 CommRelay spectator voice preference", CookieAccess_Protected);

	g_bCoreAvailable = LibraryExists(L4D2_COMMCORE_LIBRARY);
	g_bCommGuardAvailable = LibraryExists(L4D2_COMMGUARD_LIBRARY);

	HookConVarChange(g_cvVoiceEnabled, Relay_OnConVarChanged);
	HookConVarChange(g_cvVoiceDefaultEnabled, Relay_OnConVarChanged);
	HookConVarChange(g_cvVoiceSurvivor, Relay_OnConVarChanged);
	HookConVarChange(g_cvVoiceInfected, Relay_OnConVarChanged);
	HookConVarChange(g_cvChatEnabled, Relay_OnConVarChanged);
	HookConVarChange(g_cvChatSpecTeam, Relay_OnConVarChanged);
	HookConVarChange(g_cvChatSourceTVTeam, Relay_OnConVarChanged);
	L4D2CS_NormalLogToFileEx(g_cvLogMode, L4D2_COMMSUITE_COMMRELAY_LOG_PREFIX, "startup", "Plugin started. version=%s core=%d guard=%d", L4D2_COMMRELAY_VERSION, g_bCoreAvailable ? 1 : 0, g_bCommGuardAvailable ? 1 : 0);

	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);

	RegConsoleCmd("sm_hear", Command_ToggleVoice);
	RegConsoleCmd("sm_listen", Command_ToggleVoice);
	RegAdminCmd("sm_l4d2_commrelay_status", Command_Status, ADMFLAG_GENERIC, "Show L4D2 CommRelay status.");

	for (int client = 1; client <= MaxClients; client++)
	{
		g_bVoiceEnabledByClient[client] = true;
		if (AreClientCookiesCached(client))
		{
			OnClientCookiesCached(client);
		}
	}

	L4D2CS_EnsureAutoExecFolder();
	AutoExecConfig(true, "l4d2_commrelay", L4D2_COMMSUITE_AUTOEXEC_FOLDER);
	Relay_LogFormatted(Debug_General, "debug", "Plugin started. core=%d commguard=%d version=%s", g_bCoreAvailable, g_bCommGuardAvailable, L4D2_COMMRELAY_VERSION);
}

public void OnAllPluginsLoaded()
{
	g_bCoreAvailable = LibraryExists(L4D2_COMMCORE_LIBRARY);
	g_bCommGuardAvailable = LibraryExists(L4D2_COMMGUARD_LIBRARY);
	Relay_LogFormatted(Debug_General, "debug", "OnAllPluginsLoaded. core=%d commguard=%d", g_bCoreAvailable, g_bCommGuardAvailable);
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, L4D2_COMMCORE_LIBRARY))
	{
		g_bCoreAvailable = true;
		Relay_LogFormatted(Debug_General, "debug", "Library added: %s", name);
		return;
	}

	if (StrEqual(name, L4D2_COMMGUARD_LIBRARY))
	{
		g_bCommGuardAvailable = true;
		Relay_LogFormatted(Debug_General, "debug", "Library added: %s", name);
		QueueRefreshAllVoiceOverrides();
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, L4D2_COMMCORE_LIBRARY))
	{
		g_bCoreAvailable = false;
		Relay_LogFormatted(Debug_General, "debug", "Library removed: %s", name);
		return;
	}

	if (StrEqual(name, L4D2_COMMGUARD_LIBRARY))
	{
		g_bCommGuardAvailable = false;
		Relay_LogFormatted(Debug_General, "debug", "Library removed: %s", name);
		QueueRefreshAllVoiceOverrides();
	}
}

public void OnPluginEnd()
{
	ResetAllVoiceOverrides();
}

public void OnConfigsExecuted()
{
	QueueRefreshAllVoiceOverrides();
}

public void OnClientPutInServer(int client)
{
	g_bVoiceEnabledByClient[client] = g_cvVoiceDefaultEnabled != null ? g_cvVoiceDefaultEnabled.BoolValue : true;
	g_bCookiesCached[client] = false;
	g_bPendingCookieSave[client] = false;

	if (AreClientCookiesCached(client))
	{
		OnClientCookiesCached(client);
	}

	RefreshClientVoiceOverrides(client);
}

public void OnClientPostAdminCheck(int client)
{
	RefreshClientVoiceOverrides(client);
}

public void OnClientDisconnect(int client)
{
	ResetVoiceOverridesForSender(client);
	g_bVoiceEnabledByClient[client] = true;
	g_bCookiesCached[client] = false;
	g_bPendingCookieSave[client] = false;
	QueueRefreshAllVoiceOverrides();
}

public void OnClientCookiesCached(int client)
{
	if (!L4D2CS_IsValidClientIndex(client))
	{
		return;
	}

	g_bCookiesCached[client] = true;

	if (g_bPendingCookieSave[client])
	{
		SaveVoicePreference(client);
		g_bPendingCookieSave[client] = false;
	}
	else
	{
		LoadVoicePreference(client);
	}

	if (IsHumanClient(client))
	{
		RefreshClientVoiceOverrides(client);
	}
}

public void L4D2Comm_OnChatMessage_Post(int client, L4D2CommChannel channel, const char[] text)
{
	if (!g_bCoreAvailable || g_cvChatEnabled == null || !g_cvChatEnabled.BoolValue)
	{
		return;
	}

	if (channel != L4D2CommChannel_Team || !IsHumanClient(client))
	{
		return;
	}

	if (IsChatTrigger())
	{
		Relay_LogFormatted(Debug_Chat, "chat", "Skipped relay because message is a chat trigger. client=%d", client);
		return;
	}

	L4DTeam authorTeam = L4D_GetClientTeam(client);
	if (authorTeam != L4DTeam_Survivor && authorTeam != L4DTeam_Infected)
	{
		return;
	}

	char teamLabel[16];
	L4D2CS_GetTeamLabel(authorTeam, teamLabel, sizeof(teamLabel));

	for (int target = 1; target <= MaxClients; target++)
	{
		if (!Relay_ShouldRelayTeamChatToTarget(client, target, authorTeam))
		{
			continue;
		}

		CPrintToChatEx(target, client, "{olive}(%s){default} {teamcolor}%N{default}: %s", teamLabel, client, text);
	}

	Relay_LogFormatted(Debug_Chat, "chat", "Relayed team chat. author=%N team=%d text=%s", client, authorTeam, text);
}

public void L4D2CommGuard_OnClientVoiceBlockChanged(int client, bool blocked)
{
	L4D2CS_NormalLogToFileEx(g_cvLogMode, L4D2_COMMSUITE_COMMRELAY_LOG_PREFIX, "state", "subject=voice_block client=%N blocked=%d", client, blocked ? 1 : 0);
	Relay_LogFormatted(Debug_Voice, "voice", "Voice block state changed. client=%d blocked=%d", client, blocked);
	QueueRefreshAllVoiceOverrides();
}

public any Native_IsVoiceEnabled(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return L4D2CS_IsValidClientIndex(client) && g_bVoiceEnabledByClient[client];
}

public any Native_SetVoiceEnabled(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	bool enabled = view_as<bool>(GetNativeCell(2));
	bool saveCookie = numParams >= 3 ? view_as<bool>(GetNativeCell(3)) : true;

	if (!IsHumanClient(client))
	{
		return false;
	}

	SetClientVoiceEnabledInternal(client, enabled, saveCookie, false);
	return true;
}

public Action Command_ToggleVoice(int client, int args)
{
	if (client <= 0)
	{
		CReplyToCommand(client, "%s This command can only be used in-game.", L4D2_COMMSUITE_COMMRELAY_PREFIX);
		return Plugin_Handled;
	}

	if (!CanUseVoiceRelay(client, true))
	{
		return Plugin_Handled;
	}

	if (args < 1)
	{
		SetClientVoiceEnabledInternal(client, !g_bVoiceEnabledByClient[client], true, true);
		return Plugin_Handled;
	}

	char arg[16];
	GetCmdArg(1, arg, sizeof(arg));

	if (StrEqual(arg, "on", false) || StrEqual(arg, "enable", false))
	{
		SetClientVoiceEnabledInternal(client, true, true, true);
	}
	else if (StrEqual(arg, "off", false) || StrEqual(arg, "disable", false))
	{
		SetClientVoiceEnabledInternal(client, false, true, true);
	}
	else if (StrEqual(arg, "status", false))
	{
		ReplyVoiceStatus(client);
	}
	else
	{
		CReplyToCommand(client, "%s Usage: {green}sm_hear [on|off|status]{default}", L4D2_COMMSUITE_COMMRELAY_PREFIX);
	}

	return Plugin_Handled;
}

public Action Command_Status(int client, int args)
{
	CReplyToCommand(
		client,
		"%s core={green}%d{default} commguard={green}%d{default} debug_mask={green}%d{default} chat={green}%d{default} chat_spec={green}%d{default} chat_sourcetv={green}%d{default} voice={green}%d{default} voice_default={green}%d{default} voice_survivor={green}%d{default} voice_infected={green}%d{default}",
		L4D2_COMMSUITE_COMMRELAY_PREFIX,
		g_bCoreAvailable,
		g_bCommGuardAvailable,
		g_cvDebugMask != null ? g_cvDebugMask.IntValue : 0,
		g_cvChatEnabled != null && g_cvChatEnabled.BoolValue,
		g_cvChatSpecTeam != null && g_cvChatSpecTeam.BoolValue,
		g_cvChatSourceTVTeam != null && g_cvChatSourceTVTeam.BoolValue,
		g_cvVoiceEnabled != null && g_cvVoiceEnabled.BoolValue,
		g_cvVoiceDefaultEnabled != null && g_cvVoiceDefaultEnabled.BoolValue,
		g_cvVoiceSurvivor != null && g_cvVoiceSurvivor.BoolValue,
		g_cvVoiceInfected != null && g_cvVoiceInfected.BoolValue
	);

	if (client > 0 && IsHumanClient(client))
	{
		CReplyToCommand(client, "%s client_voice_enabled={green}%d{default} team={green}%d{default}", L4D2_COMMSUITE_COMMRELAY_PREFIX, g_bVoiceEnabledByClient[client], L4D_GetClientTeam(client));
	}

	return Plugin_Handled;
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if (event.GetBool("disconnect"))
	{
		return;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsHumanClient(client))
	{
		return;
	}

	Relay_LogFormatted(Debug_Voice, "voice", "player_team refresh for %N team=%d", client, view_as<L4DTeam>(event.GetInt("team")));
	QueueRefreshAllVoiceOverrides();
}

/**
 * Handles shared convar changes that affect relay behavior.
 *
 * @param convar        Updated cvar.
 * @param oldValue      Previous value.
 * @param newValue      New value.
 */
void Relay_OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char convarName[64];
	if (convar != null)
	{
		convar.GetName(convarName, sizeof(convarName));
	}
	else
	{
		strcopy(convarName, sizeof(convarName), "unknown");
	}

	Relay_LogFormatted(Debug_General, "debug", "ConVar changed: %s=%s", convarName, newValue);
	QueueRefreshAllVoiceOverrides();
}

bool DebugEnabled(RelayDebugMask debugMask)
{
	return L4D2CS_DebugMaskEnabled(g_cvLogMode, g_cvDebugMask, view_as<int>(debugMask));
}

/**
 * Emits a formatted log line for the unified relay runtime.
 *
 * @param debugMask     Debug category required for the message.
 * @param tag           Log tag shown in the prefix.
 * @param format        Format string.
 */
void Relay_LogFormatted(RelayDebugMask debugMask, const char[] tag, const char[] format, any ...)
{
	if (!DebugEnabled(debugMask))
	{
		return;
	}

	static char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 4);
	LogToFileEx(g_sLogPath, "%s[%s] %s", L4D2_COMMSUITE_COMMRELAY_LOG_PREFIX, tag, buffer);
}

bool IsHumanSpectator(int client)
{
	return IsHumanClient(client) && L4D_GetClientTeam(client) == L4DTeam_Spectator;
}

bool Relay_ShouldRelayTeamChatToTarget(int author, int target, L4DTeam authorTeam)
{
	if (!L4D2CS_IsConnectedClient(target) || !IsClientInGame(target) || target == author)
	{
		return false;
	}

	if (IsClientSourceTV(target) || IsClientReplay(target))
	{
		return g_cvChatSourceTVTeam != null && g_cvChatSourceTVTeam.BoolValue;
	}

	if (!IsHumanSpectator(target))
	{
		return false;
	}

	if (authorTeam != L4DTeam_Survivor && authorTeam != L4DTeam_Infected)
	{
		return false;
	}

	return g_cvChatSpecTeam != null && g_cvChatSpecTeam.BoolValue;
}

bool CanUseVoiceRelay(int client, bool notify)
{
	if (!IsHumanClient(client))
	{
		return false;
	}

	if (L4D_GetClientTeam(client) == L4DTeam_Spectator)
	{
		return true;
	}

	if (notify)
	{
		CReplyToCommand(client, "%s This command is only available to spectators.", L4D2_COMMSUITE_COMMRELAY_PREFIX);
	}

	return false;
}

bool IsVoiceRelayTeamEnabled(L4DTeam team)
{
	switch (team)
	{
		case L4DTeam_Survivor:
		{
			return g_cvVoiceSurvivor != null && g_cvVoiceSurvivor.BoolValue;
		}
		case L4DTeam_Infected:
		{
			return g_cvVoiceInfected != null && g_cvVoiceInfected.BoolValue;
		}
	}

	return false;
}

void LoadVoicePreference(int client)
{
	char value[4];
	GetClientCookie(client, g_hCookieVoiceEnabled, value, sizeof(value));

	if (value[0] == '\0')
	{
		g_bVoiceEnabledByClient[client] = g_cvVoiceDefaultEnabled != null ? g_cvVoiceDefaultEnabled.BoolValue : true;
		return;
	}

	g_bVoiceEnabledByClient[client] = StringToInt(value) != 0;
}

void SaveVoicePreference(int client)
{
	SetClientCookie(client, g_hCookieVoiceEnabled, g_bVoiceEnabledByClient[client] ? "1" : "0");
}

void ReplyVoiceStatus(int client)
{
	CReplyToCommand(
		client,
		"%s voice={green}%d{default} client_voice_enabled={green}%d{default} survivor={green}%d{default} infected={green}%d{default} commguard={green}%d{default}",
		L4D2_COMMSUITE_COMMRELAY_PREFIX,
		g_cvVoiceEnabled != null && g_cvVoiceEnabled.BoolValue,
		g_bVoiceEnabledByClient[client],
		g_cvVoiceSurvivor != null && g_cvVoiceSurvivor.BoolValue,
		g_cvVoiceInfected != null && g_cvVoiceInfected.BoolValue,
		g_bCommGuardAvailable
	);
}

void SetClientVoiceEnabledInternal(int client, bool enabled, bool saveCookie, bool notify)
{
	if (!CanUseVoiceRelay(client, notify))
	{
		return;
	}

	g_bVoiceEnabledByClient[client] = enabled;

	if (saveCookie)
	{
		if (g_bCookiesCached[client])
		{
			SaveVoicePreference(client);
		}
		else
		{
			g_bPendingCookieSave[client] = true;
		}
	}

	RefreshClientVoiceOverrides(client);

	if (notify)
	{
		CReplyToCommand(client, "%s Spectator voice relay {green}%s{default}.", L4D2_COMMSUITE_COMMRELAY_PREFIX, enabled ? "enabled" : "disabled");
	}
}

void ResetAllVoiceOverrides()
{
	for (int receiver = 1; receiver <= MaxClients; receiver++)
	{
		if (!IsHumanClient(receiver))
		{
			continue;
		}

		for (int sender = 1; sender <= MaxClients; sender++)
		{
			if (sender == receiver)
			{
				continue;
			}

			SetListenOverride(receiver, sender, Listen_Default);
		}
	}
}

void ResetVoiceOverridesForSender(int sender)
{
	if (!L4D2CS_IsValidClientIndex(sender))
	{
		return;
	}

	for (int receiver = 1; receiver <= MaxClients; receiver++)
	{
		if (!IsHumanClient(receiver) || receiver == sender)
		{
			continue;
		}

		if (GetListenOverride(receiver, sender) != Listen_Default)
		{
			SetListenOverride(receiver, sender, Listen_Default);
		}
	}
}

void QueueRefreshAllVoiceOverrides()
{
	if (g_bVoiceRefreshQueued)
	{
		return;
	}

	g_bVoiceRefreshQueued = true;
	RequestFrame(Frame_RefreshAllVoiceOverrides);
}

public void Frame_RefreshAllVoiceOverrides(any data)
{
	g_bVoiceRefreshQueued = false;
	RefreshAllVoiceOverrides();
}

void RefreshAllVoiceOverrides()
{
	for (int receiver = 1; receiver <= MaxClients; receiver++)
	{
		RefreshClientVoiceOverrides(receiver);
	}
}

void RefreshClientVoiceOverrides(int receiver)
{
	if (!IsHumanClient(receiver))
	{
		return;
	}

	bool manageReceiver = g_cvVoiceEnabled != null && g_cvVoiceEnabled.BoolValue && IsHumanSpectator(receiver);

	for (int sender = 1; sender <= MaxClients; sender++)
	{
		if (!IsHumanClient(sender) || sender == receiver)
		{
			continue;
		}

		ListenOverride desired = Listen_Default;
		L4DTeam senderTeam = L4D_GetClientTeam(sender);

		if (senderTeam == L4DTeam_Survivor || senderTeam == L4DTeam_Infected)
		{
			if (manageReceiver)
			{
				if (!g_bVoiceEnabledByClient[receiver])
				{
					desired = Listen_No;
				}
				else if (!IsVoiceRelayTeamEnabled(senderTeam))
				{
					desired = Listen_No;
				}
				else if (g_bCommGuardAvailable && L4D2CommGuard_IsClientVoiceBlocked(sender))
				{
					desired = Listen_No;
				}
				else
				{
					desired = Listen_Yes;
				}
			}
		}

		if (GetListenOverride(receiver, sender) != desired)
		{
			SetListenOverride(receiver, sender, desired);
		}
	}

	Relay_LogFormatted(Debug_Voice, "voice", "Refreshed overrides for %N manage=%d enabled=%d", receiver, manageReceiver, g_bVoiceEnabledByClient[receiver]);
}
