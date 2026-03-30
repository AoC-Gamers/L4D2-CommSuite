#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>

#undef REQUIRE_PLUGIN
#include <basecomm>
#include <bansystem_comm>
#include <sourcecomms>
#define REQUIRE_PLUGIN

#include <l4d2_commcore>
#include <l4d2_commguard>
#include <l4d2_commsuite_shared>

/**
 * Debug bit flags for CommGuard runtime logging.
 */
enum L4D2CommGuardDebugMask
{
	Debug_General = 1,
	Debug_Provider = 2,
	Debug_External = 4
};

#define L4D2_COMMGUARD_NORMAL_LOG_FILE "l4d2_commguard.log"

ConVar g_cvDebugMask = null;
ConVar g_cvChatEnabled = null;
ConVar g_cvVoiceEnabled = null;
ConVar g_cvLogMode = null;

bool g_bCoreLibrary = false;
bool g_bBaseCommLibrary = false;
bool g_bBanSystemCommLibrary = false;
bool g_bSourceCommsLibrary = false;
bool g_bLateLoad = false;
bool g_bVoiceBlocked[MAXPLAYERS + 1];
L4D2CommGuardProvider g_eLastLoggedProvider = Provider_None;
bool g_bLastLoggedProviderValid = false;
char g_sLogPath[PLATFORM_MAX_PATH];

Handle g_fwdChatBlockCheck = INVALID_HANDLE;
Handle g_fwdVoiceBlockCheck = INVALID_HANDLE;
Handle g_fwdVoiceBlockResolved = INVALID_HANDLE;
Handle g_fwdVoiceBlockChanged = INVALID_HANDLE;

public Plugin myinfo =
{
	name = "L4D2 CommGuard",
	author = "lechuga",
	description = "Unified chat and voice guard for L4D2 CommSuite.",
	version = L4D2_COMMGUARD_VERSION,
	url = "https://github.com/AoC-Gamers/L4D2-CommSuite"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int errMax)
{
	RegPluginLibrary(L4D2_COMMGUARD_LIBRARY);
	g_bLateLoad = late;

	g_fwdChatBlockCheck = CreateGlobalForward("L4D2CommGuard_OnChatBlockCheck", ET_Hook, Param_Cell, Param_Cell, Param_String);
	g_fwdVoiceBlockCheck = CreateGlobalForward("L4D2CommGuard_OnVoiceBlockCheck", ET_Hook, Param_Cell);
	g_fwdVoiceBlockResolved = CreateGlobalForward("L4D2CommGuard_OnVoiceBlockResolved", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_fwdVoiceBlockChanged = CreateGlobalForward("L4D2CommGuard_OnClientVoiceBlockChanged", ET_Ignore, Param_Cell, Param_Cell);

	CreateNative("L4D2CommGuard_IsClientChatBlocked", Native_L4D2CommGuard_IsClientChatBlocked);
	CreateNative("L4D2CommGuard_IsClientVoiceBlocked", Native_L4D2CommGuard_IsClientVoiceBlocked);
	CreateNative("L4D2CommGuard_GetLoadedProviderMask", Native_L4D2CommGuard_GetLoadedProviderMask);
	CreateNative("L4D2CommGuard_GetActiveProvider", Native_L4D2CommGuard_GetActiveProvider);
	L4D2CommGuard_RefreshLibraryState();
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_cvLogMode = L4D2CS_FindOrCreatePluginLogModeConVar("l4d2_commguard_log_mode", "L4D2 CommGuard log mode. 0=off, 1=normal, 2=debug.");
	g_cvDebugMask = CreateConVar("l4d2_commguard_debug_mask", "0", "Debug bitmask. 1=general 2=provider 4=external (all=7).", FCVAR_NONE, true, 0.0, true, 7.0);
	g_cvChatEnabled = CreateConVar("l4d2_commguard_chat_enabled", "1", "Enable chat guard checks.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvVoiceEnabled = CreateConVar("l4d2_commguard_voice_enabled", "1", "Enable voice guard checks.", FCVAR_NONE, true, 0.0, true, 1.0);
	L4D2CS_BuildLogPath("l4d2_commguard.log", g_sLogPath, sizeof(g_sLogPath));

	RegAdminCmd("sm_l4d2_commguard_status", Command_L4D2CommGuard_Status, ADMFLAG_GENERIC, "Show L4D2 CommGuard status.");

	L4D2CS_EnsureAutoExecFolder();
	AutoExecConfig(true, "l4d2_commguard", L4D2_COMMSUITE_AUTOEXEC_FOLDER);

	if (!g_bLateLoad)
		return;

	L4D2CommGuard_RefreshLibraryState();
	L4D2CommGuard_RefreshAllVoiceStates();
}

public void OnAllPluginsLoaded()
{
	L4D2CommGuard_RefreshLibraryState();
	L4D2CommGuard_RefreshAllVoiceStates();
}

public void OnLibraryAdded(const char[] name)
{
	bool refreshVoiceStates = false;

	if (StrEqual(name, L4D2_COMMCORE_LIBRARY))
	{
		g_bCoreLibrary = true;
	}
	else if (StrEqual(name, L4D2_COMMSUITE_BASECOMM_LIBRARY))
	{
		g_bBaseCommLibrary = true;
		refreshVoiceStates = true;
	}
	else if (StrEqual(name, L4D2_COMMSUITE_BANSYSTEM_COMM_LIBRARY))
	{
		g_bBanSystemCommLibrary = true;
		refreshVoiceStates = true;
	}
	else if (StrEqual(name, L4D2_COMMSUITE_SOURCECOMMS_LIBRARY))
	{
		g_bSourceCommsLibrary = true;
		refreshVoiceStates = true;
	}
	else
	{
		return;
	}

	if (!refreshVoiceStates)
		return;

	L4D2CommGuard_SyncProviderState();
	L4D2CommGuard_RefreshAllVoiceStates();
}

public void OnLibraryRemoved(const char[] name)
{
	bool refreshVoiceStates = false;

	if (StrEqual(name, L4D2_COMMCORE_LIBRARY))
	{
		g_bCoreLibrary = false;
	}
	else if (StrEqual(name, L4D2_COMMSUITE_BASECOMM_LIBRARY))
	{
		g_bBaseCommLibrary = false;
		refreshVoiceStates = true;
	}
	else if (StrEqual(name, L4D2_COMMSUITE_BANSYSTEM_COMM_LIBRARY))
	{
		g_bBanSystemCommLibrary = false;
		refreshVoiceStates = true;
	}
	else if (StrEqual(name, L4D2_COMMSUITE_SOURCECOMMS_LIBRARY))
	{
		g_bSourceCommsLibrary = false;
		refreshVoiceStates = true;
	}
	else
	{
		return;
	}

	if (!refreshVoiceStates)
		return;

	L4D2CommGuard_SyncProviderState();
	L4D2CommGuard_RefreshAllVoiceStates();
}

public void OnConfigsExecuted()
{
	L4D2CS_EnsureDebugLogFolderForMode(g_cvLogMode);
	L4D2CommGuard_RefreshAllVoiceStates();
}

public void OnClientPutInServer(int client)
{
	g_bVoiceBlocked[client] = false;
}

public void OnClientPostAdminCheck(int client)
{
	L4D2CommGuard_RefreshVoiceState(client, true);
}

public void OnClientDisconnect(int client)
{
	g_bVoiceBlocked[client] = false;
}

public void BaseComm_OnClientMute(int client, bool muteState)
{
	L4D2CommGuard_RefreshVoiceStateFromProvider(client, "voice: BaseComm_OnClientMute client=%N state=%d", client, muteState);
}

public void SourceComms_OnBlockAdded(int client, int target, int time, int type, char[] reason)
{
	if (type != TYPE_MUTE && type != TYPE_SILENCE)
	{
		return;
	}

	L4D2CommGuard_RefreshVoiceStateFromProvider(target, "voice: SourceComms_OnBlockAdded target=%N type=%d", target, type);
}

public void SourceComms_OnBlockRemoved(int client, int target, int type, char[] reason)
{
	if (type != TYPE_UNMUTE && type != TYPE_UNSILENCE && type != TYPE_TEMP_UNMUTE && type != TYPE_TEMP_UNSILENCE)
	{
		return;
	}

	L4D2CommGuard_RefreshVoiceStateFromProvider(target, "voice: SourceComms_OnBlockRemoved target=%N type=%d", target, type);
}

public void BSComm_OnClientCommStateChanged(int client, bool blocked, eBSCommType commType)
{
	if (!IsHumanClient(client))
	{
		return;
	}

	L4D2CommGuard_RefreshVoiceStateFromProvider(
		client,
		"voice: BSComm_OnClientCommStateChanged client=%N blocked=%d comm_type=%d",
		client,
		blocked ? 1 : 0,
		view_as<int>(commType)
	);
}

public any Native_L4D2CommGuard_IsClientChatBlocked(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	L4D2CommChannel channel = view_as<L4D2CommChannel>(GetNativeCell(2));

	char text[256];
	if (numParams >= 3)
	{
		GetNativeString(3, text, sizeof(text));
	}
	else
	{
		text[0] = '\0';
	}

	return L4D2CommGuard_ShouldBlockChat(client, channel, text);
}

public any Native_L4D2CommGuard_IsClientVoiceBlocked(Handle plugin, int numParams)
{
	return L4D2CommGuard_ShouldBlockVoice(GetNativeCell(1));
}

public any Native_L4D2CommGuard_GetLoadedProviderMask(Handle plugin, int numParams)
{
	return L4D2CommGuard_GetLoadedProviderMaskInternal();
}

public any Native_L4D2CommGuard_GetActiveProvider(Handle plugin, int numParams)
{
	return view_as<int>(L4D2CommGuard_GetActiveProviderInternal());
}

bool L4D2CommGuard_DebugEnabled(L4D2CommGuardDebugMask debugMask)
{
	return L4D2CS_DebugMaskEnabled(g_cvLogMode, g_cvDebugMask, view_as<int>(debugMask));
}

void L4D2CommGuard_LogLine(const char[] tag, const char[] message)
{
	LogToFileEx(g_sLogPath, "%s[%s] %s", L4D2_COMMSUITE_COMMGUARD_LOG_PREFIX, tag, message);
}

/**
 * Logs a provider-driven voice state change and refreshes the cached block state.
 *
 * @param client        Client index.
 * @param format        Formatting rules.
 * @param ...           Formatting parameters.
 */
void L4D2CommGuard_RefreshVoiceStateFromProvider(int client, const char[] format, any ...)
{
	if (!IsHumanClient(client))
	{
		return;
	}

	static char buffer[256];
	VFormat(buffer, sizeof(buffer), format, 3);
	L4D2CommGuard_LogFormatted(Debug_Provider, "provider", "%s", buffer);
	L4D2CommGuard_RefreshVoiceState(client, true);
}

/**
 * Writes one debug/provider/external line if the requested debug bit is enabled.
 *
 * @param debugMask     Debug category to test.
 * @param tag           Log tag written in the prefix.
 * @param format        Formatting rules.
 * @param ...           Formatting parameters.
 */
void L4D2CommGuard_LogFormatted(L4D2CommGuardDebugMask debugMask, const char[] tag, const char[] format, any ...)
{
	if (!L4D2CommGuard_DebugEnabled(debugMask))
	{
		return;
	}

	static char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 4);
	L4D2CommGuard_LogLine(tag, buffer);
}

void L4D2CommGuard_SyncProviderState()
{
	L4D2CommGuardProvider activeProvider = L4D2CommGuard_GetActiveProviderInternal();
	if (!g_bLastLoggedProviderValid || g_eLastLoggedProvider != activeProvider)
	{
		if (activeProvider == Provider_None)
		{
			L4D2CommGuard_LogFormatted(Debug_Provider, "provider", "active=none loaded_mask=%d", view_as<int>(L4D2CommGuard_GetLoadedProviderMaskInternal()));
		}
		else
		{
			char providerName[32];
			L4D2CommGuard_FormatProviderName(activeProvider, providerName, sizeof(providerName));
			L4D2CommGuard_LogFormatted(Debug_Provider, "provider", "active=%s loaded_mask=%d", providerName, view_as<int>(L4D2CommGuard_GetLoadedProviderMaskInternal()));
		}

		g_eLastLoggedProvider = activeProvider;
		g_bLastLoggedProviderValid = true;
	}

	if (activeProvider == Provider_None)
	{
		L4D2CommGuard_LogFormatted(Debug_General, "debug", "No punishment provider loaded.");
	}
}

/**
 * Refreshes runtime library state from currently loaded plugins.
 */
void L4D2CommGuard_RefreshLibraryState()
{
	g_bCoreLibrary = LibraryExists(L4D2_COMMCORE_LIBRARY);
	g_bBaseCommLibrary = LibraryExists(L4D2_COMMSUITE_BASECOMM_LIBRARY);
	g_bBanSystemCommLibrary = LibraryExists(L4D2_COMMSUITE_BANSYSTEM_COMM_LIBRARY);
	g_bSourceCommsLibrary = LibraryExists(L4D2_COMMSUITE_SOURCECOMMS_LIBRARY);
	L4D2CommGuard_SyncProviderState();
}

/**
 * Returns a bitmask of loaded punishment providers.
 *
 * @return              Loaded provider mask.
 */
L4D2CommGuardProvider L4D2CommGuard_GetLoadedProviderMaskInternal()
{
	L4D2CommGuardProvider mask = Provider_None;

	if (g_bBaseCommLibrary)
	{
		mask |= Provider_BaseComm;
	}

	if (g_bSourceCommsLibrary)
	{
		mask |= Provider_SourceComms;
	}

	if (g_bBanSystemCommLibrary)
	{
		mask |= Provider_BanSystemComm;
	}

	return mask;
}

/**
 * Returns the provider currently used by CommGuard.
 *
 * The first loaded provider wins.
 *
 * @return              Active provider, or Provider_None.
 */
L4D2CommGuardProvider L4D2CommGuard_GetActiveProviderInternal()
{
	if (g_bBanSystemCommLibrary)
	{
		return Provider_BanSystemComm;
	}

	if (g_bSourceCommsLibrary)
	{
		return Provider_SourceComms;
	}

	if (g_bBaseCommLibrary)
	{
		return Provider_BaseComm;
	}

	return Provider_None;
}

void L4D2CommGuard_AppendProviderName(char[] buffer, int maxlen, const char[] label)
{
	if (buffer[0] != '\0')
	{
		StrCat(buffer, maxlen, ",");
	}

	StrCat(buffer, maxlen, label);
}

void L4D2CommGuard_FormatLoadedProviders(L4D2CommGuardProvider mask, char[] buffer, int maxlen)
{
	buffer[0] = '\0';

	if (mask == Provider_None)
	{
		strcopy(buffer, maxlen, "none");
		return;
	}

	if ((mask & Provider_BanSystemComm) != Provider_None)
	{
		L4D2CommGuard_AppendProviderName(buffer, maxlen, "bansystem_comm");
	}

	if ((mask & Provider_SourceComms) != Provider_None)
	{
		L4D2CommGuard_AppendProviderName(buffer, maxlen, "sourcecomms");
	}

	if ((mask & Provider_BaseComm) != Provider_None)
	{
		L4D2CommGuard_AppendProviderName(buffer, maxlen, "basecomm");
	}
}

void L4D2CommGuard_FormatProviderName(L4D2CommGuardProvider provider, char[] buffer, int maxlen)
{
	switch (provider)
	{
		case Provider_BanSystemComm:
		{
			strcopy(buffer, maxlen, "bansystem_comm");
		}
		case Provider_SourceComms:
		{
			strcopy(buffer, maxlen, "sourcecomms");
		}
		case Provider_BaseComm:
		{
			strcopy(buffer, maxlen, "basecomm");
		}
		default:
		{
			strcopy(buffer, maxlen, "none");
		}
	}
}

/**
 * Checks whether the active provider currently blocks text chat for the client.
 *
 * @param client        Client index.
 * @return              True if provider state blocks chat.
 */
bool L4D2CommGuard_IsChatBlockedByProvider(int client)
{
	switch (L4D2CommGuard_GetActiveProviderInternal())
	{
		case Provider_BanSystemComm:
		{
			if (BSComm_IsClientBanned(client))
			{
				eBSCommType commType = BSComm_GetResolvedCommType(client);
				if (commType == kBSCommType_Chat || commType == kBSCommType_All)
				{
					L4D2CommGuard_LogFormatted(Debug_Provider, "provider", "chat: blocked by BanSystem Comm. client=%N comm_type=%d", client, commType);
					return true;
				}
			}
		}
		case Provider_SourceComms:
		{
			bType gagType = SourceComms_GetClientGagType(client);
			if (gagType != bNot)
			{
				L4D2CommGuard_LogFormatted(Debug_Provider, "provider", "chat: blocked by SourceComms++. client=%N gag_type=%d", client, gagType);
				return true;
			}
		}
		case Provider_BaseComm:
		{
			if (BaseComm_IsClientGagged(client))
			{
				L4D2CommGuard_LogFormatted(Debug_Provider, "provider", "chat: blocked by BaseComm. client=%N", client);
				return true;
			}
		}
	}

	return false;
}

/**
 * Calls the external chat-block forward exposed by CommGuard.
 *
 * @param client        Client index.
 * @param channel       Chat channel.
 * @param text          Chat text.
 * @return              Action returned by the forward chain.
 */
Action L4D2CommGuard_CallChatForward(int client, L4D2CommChannel channel, const char[] text)
{
	if (g_fwdChatBlockCheck == INVALID_HANDLE)
	{
		return Plugin_Continue;
	}

	Action result = Plugin_Continue;
	Call_StartForward(g_fwdChatBlockCheck);
	Call_PushCell(client);
	Call_PushCell(channel);
	Call_PushString(text);
	Call_Finish(result);

	L4D2CommGuard_LogFormatted(Debug_External, "external", "chat: external guard finished. client=%d channel=%d result=%d", client, channel, result);
	return result;
}

/**
 * Resolves whether the current chat message should be blocked.
 *
 * @param client        Client index.
 * @param channel       Chat channel.
 * @param text          Chat text.
 * @return              True if chat should be blocked.
 */
bool L4D2CommGuard_ShouldBlockChat(int client, L4D2CommChannel channel, const char[] text)
{
	if (!IsHumanClient(client) || g_cvChatEnabled == null || !g_cvChatEnabled.BoolValue)
	{
		return false;
	}

	if (L4D2CommGuard_IsChatBlockedByProvider(client))
	{
		return true;
	}

	return L4D2CommGuard_CallChatForward(client, channel, text) >= Plugin_Handled;
}

public Action L4D2Comm_OnChatMessage(int client, L4D2CommChannel channel, const char[] text)
{
	if (!g_bCoreLibrary || !IsHumanClient(client))
	{
		return Plugin_Continue;
	}

	if (L4D2CommGuard_ShouldBlockChat(client, channel, text))
	{
		L4D2CommGuard_LogFormatted(Debug_General, "debug", "chat: blocked. client=%N channel=%d text=%s", client, channel, text);
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

/**
 * Checks whether the active provider currently blocks voice for the client.
 *
 * @param client        Client index.
 * @return              True if provider state blocks voice.
 */
bool L4D2CommGuard_IsVoiceBlockedByProvider(int client)
{
	switch (L4D2CommGuard_GetActiveProviderInternal())
	{
		case Provider_BanSystemComm:
		{
			if (BSComm_IsClientBanned(client))
			{
				eBSCommType commType = BSComm_GetResolvedCommType(client);
				if (commType == kBSCommType_Mic || commType == kBSCommType_All)
				{
					L4D2CommGuard_LogFormatted(Debug_Provider, "provider", "voice: blocked by BanSystem Comm. client=%N comm_type=%d", client, commType);
					return true;
				}
			}
		}
		case Provider_SourceComms:
		{
			bType muteType = SourceComms_GetClientMuteType(client);
			if (muteType != bNot)
			{
				L4D2CommGuard_LogFormatted(Debug_Provider, "provider", "voice: blocked by SourceComms++. client=%N mute_type=%d", client, muteType);
				return true;
			}
		}
		case Provider_BaseComm:
		{
			if (BaseComm_IsClientMuted(client))
			{
				L4D2CommGuard_LogFormatted(Debug_Provider, "provider", "voice: blocked by BaseComm. client=%N", client);
				return true;
			}
		}
	}

	return false;
}

/**
 * Calls the external voice-block forward exposed by CommGuard.
 *
 * @param client        Client index.
 * @return              Action returned by the forward chain.
 */
Action L4D2CommGuard_CallVoiceForward(int client)
{
	if (g_fwdVoiceBlockCheck == INVALID_HANDLE)
	{
		return Plugin_Continue;
	}

	Action result = Plugin_Continue;
	Call_StartForward(g_fwdVoiceBlockCheck);
	Call_PushCell(client);
	Call_Finish(result);
	L4D2CommGuard_LogFormatted(Debug_External, "external", "voice: external guard finished. client=%N result=%d", client, result);
	return result;
}

/**
 * Resolves whether the current client should be treated as voice-blocked.
 *
 * @param client        Client index.
 * @return              True if voice should be blocked.
 */
bool L4D2CommGuard_ShouldBlockVoice(int client)
{
	if (!IsHumanClient(client) || g_cvVoiceEnabled == null || !g_cvVoiceEnabled.BoolValue)
	{
		return false;
	}

	if (L4D2CommGuard_IsVoiceBlockedByProvider(client))
	{
		return true;
	}

	Action result = L4D2CommGuard_CallVoiceForward(client);
	if (result >= Plugin_Handled)
	{
		L4D2CommGuard_LogFormatted(Debug_External, "external", "voice: blocked by external forward. client=%N result=%d", client, result);
		return true;
	}

	return false;
}

/**
 * Rebuilds cached voice-block state for all human clients.
 */
void L4D2CommGuard_RefreshAllVoiceStates()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		L4D2CommGuard_RefreshVoiceState(client, false);
	}
}

/**
 * Rebuilds cached voice-block state for one client and fires the change forward when needed.
 *
 * @param client        Client index.
 * @param verbose       True to emit a debug line when the state changes.
 */
void L4D2CommGuard_RefreshVoiceState(int client, bool verbose)
{
	if (!IsHumanClient(client))
	{
		return;
	}

	bool blocked = L4D2CommGuard_ShouldBlockVoice(client);
	bool changed = g_bVoiceBlocked[client] != blocked;

	if (g_fwdVoiceBlockResolved != INVALID_HANDLE)
	{
		Call_StartForward(g_fwdVoiceBlockResolved);
		Call_PushCell(client);
		Call_PushCell(blocked ? 1 : 0);
		Call_PushCell(changed ? 1 : 0);
		Call_Finish();
	}

	if (!changed)
	{
		return;
	}

	g_bVoiceBlocked[client] = blocked;

	if (verbose)
	{
		L4D2CommGuard_LogFormatted(Debug_General, "debug", "voice: block state changed for %N -> %d", client, blocked);
	}

	L4D2CS_NormalLogToFileEx(g_cvLogMode, L4D2_COMMGUARD_NORMAL_LOG_FILE, L4D2_COMMSUITE_COMMGUARD_LOG_PREFIX, "state", "subject=voice_block client=%N blocked=%d", client, blocked ? 1 : 0);

	if (g_fwdVoiceBlockChanged != INVALID_HANDLE)
	{
		Call_StartForward(g_fwdVoiceBlockChanged);
		Call_PushCell(client);
		Call_PushCell(blocked ? 1 : 0);
		Call_Finish();
	}
}

public Action Command_L4D2CommGuard_Status(int client, int args)
{
	L4D2CommGuardProvider loadedMask = L4D2CommGuard_GetLoadedProviderMaskInternal();
	L4D2CommGuardProvider activeProvider = L4D2CommGuard_GetActiveProviderInternal();

	char loadedProviders[64];
	char activeProviderName[32];
	L4D2CommGuard_FormatLoadedProviders(loadedMask, loadedProviders, sizeof(loadedProviders));
	L4D2CommGuard_FormatProviderName(activeProvider, activeProviderName, sizeof(activeProviderName));

	CReplyToCommand(
		client,
		"%s core={green}%d{default} loaded_mask={green}%d{default} loaded={green}%s{default} active={green}%d{default}({green}%s{default}) debug_mask={green}%d{default} chat_enabled={green}%d{default} voice_enabled={green}%d{default}",
		L4D2_COMMSUITE_COMMGUARD_PREFIX,
		g_bCoreLibrary,
		loadedMask,
		loadedProviders,
		view_as<int>(activeProvider),
		activeProviderName,
		g_cvDebugMask != null ? g_cvDebugMask.IntValue : 0,
		g_cvChatEnabled != null ? g_cvChatEnabled.BoolValue : false,
		g_cvVoiceEnabled != null ? g_cvVoiceEnabled.BoolValue : false
	);

	return Plugin_Handled;
}
