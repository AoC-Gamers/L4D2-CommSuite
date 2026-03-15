#pragma semicolon 1
#pragma newdecls required

#include <colors>
#include <sourcemod>

#include <l4d2_commcore>

#include <l4d2_commsuite_shared>

enum L4D2ChatNoiseDebugMask
{
	L4D2ChatNoiseDebug_General = 1,
	L4D2ChatNoiseDebug_Noise = 2
};

#define L4D2_CHATNOISE_VERSION "0.1.0"

ConVar g_cvDebugMask = null;
ConVar g_cvEnabled = null;
ConVar g_cvSuppressPlayerConnect = null;
ConVar g_cvSuppressPlayerDisconnect = null;
ConVar g_cvSuppressPlayerTeam = null;
ConVar g_cvSuppressServerCvar = null;
ConVar g_cvSuppressNameChange = null;
ConVar g_cvSuppressSourceModCvar = null;

bool g_bCoreAvailable = false;
char g_sLogPath[PLATFORM_MAX_PATH];

public Plugin myinfo =
{
	name = "L4D2 ChatNoise",
	author = "lechuga",
	description = "Noise filtering satellite for L4D2 CommCore.",
	version = L4D2_CHATNOISE_VERSION,
	url = "https://github.com/AoC-Gamers/L4D2-CommSuite"
};

public void OnAllPluginsLoaded()
{
	g_bCoreAvailable = LibraryExists(L4D2_COMMCORE_LIBRARY);
	L4D2CN_Debug("OnAllPluginsLoaded. core=%d", g_bCoreAvailable);
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, L4D2_COMMCORE_LIBRARY))
	{
		g_bCoreAvailable = true;
		L4D2CN_Debug("Library added: %s", name);
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, L4D2_COMMCORE_LIBRARY))
	{
		g_bCoreAvailable = false;
		L4D2CN_Debug("Library removed: %s", name);
	}
}

public void OnPluginStart()
{
	g_cvDebugMask = CreateConVar("l4d2_chatnoise_debug_mask", "0", "Debug bitmask. 1=general 2=noise (all=3).", FCVAR_NONE, true, 0.0, true, 3.0);
	g_cvEnabled = CreateConVar("l4d2_chatnoise_enabled", "1", "Enable noise filtering.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvSuppressPlayerConnect = CreateConVar("l4d2_chatnoise_suppress_player_connect", "1", "Suppress player connect chat noise.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvSuppressPlayerDisconnect = CreateConVar("l4d2_chatnoise_suppress_player_disconnect", "1", "Suppress player disconnect chat noise.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvSuppressPlayerTeam = CreateConVar("l4d2_chatnoise_suppress_player_team", "0", "Suppress player team change chat noise.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvSuppressServerCvar = CreateConVar("l4d2_chatnoise_suppress_server_cvar", "1", "Suppress server_cvar chat noise.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvSuppressNameChange = CreateConVar("l4d2_chatnoise_suppress_name_change", "1", "Suppress name change chat noise.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvSuppressSourceModCvar = CreateConVar("l4d2_chatnoise_suppress_sm_cvar_change", "1", "Suppress SourceMod cvar change activity messages routed through SayText2.", FCVAR_NONE, true, 0.0, true, 1.0);
	L4D2CS_BuildLogPath("l4d2_chatnoise.log", g_sLogPath, sizeof(g_sLogPath));

	L4D2CN_InitCommands();
	L4D2CN_Debug("Plugin started. version=%s", L4D2_CHATNOISE_VERSION);
	L4D2CS_EnsureAutoExecFolder();
	AutoExecConfig(true, "l4d2_chatnoise", L4D2_COMMSUITE_AUTOEXEC_FOLDER);
}

bool L4D2CN_DebugEnabled(int bit)
{
	return g_cvDebugMask != null && (g_cvDebugMask.IntValue & bit) != 0;
}

void L4D2CN_LogLine(const char[] tag, const char[] message)
{
	LogToFileEx(g_sLogPath, "%s[%s] %s", L4D2_COMMSUITE_CHATNOISE_LOG_PREFIX, tag, message);
}

void L4D2CN_Debug(const char[] format, any ...)
{
	if (!L4D2CN_DebugEnabled(L4D2ChatNoiseDebug_General))
	{
		return;
	}

	static char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 2);
	L4D2CN_LogLine("debug", buffer);
}

void L4D2CN_Noise(const char[] format, any ...)
{
	if (!L4D2CN_DebugEnabled(L4D2ChatNoiseDebug_Noise))
	{
		return;
	}

	static char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 2);
	L4D2CN_LogLine("noise", buffer);
}

public Action L4D2Comm_OnServerCvarMessage(const char[] cvarName, const char[] cvarValue)
{
	if (!g_bCoreAvailable || g_cvEnabled == null || !g_cvEnabled.BoolValue)
	{
		return Plugin_Continue;
	}

	L4D2CN_Noise("server_cvar received. cvar=%s value=%s", cvarName, cvarValue);

	if (g_cvSuppressServerCvar != null && g_cvSuppressServerCvar.BoolValue)
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action L4D2Comm_OnPlayerConnectMessage(const char[] playerName)
{
	if (!g_bCoreAvailable || g_cvEnabled == null || !g_cvEnabled.BoolValue)
	{
		return Plugin_Continue;
	}

	L4D2CN_Noise("player_connect received. name=%s", playerName);

	if (g_cvSuppressPlayerConnect != null && g_cvSuppressPlayerConnect.BoolValue)
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action L4D2Comm_OnPlayerDisconnectMessage(const char[] playerName, const char[] reason)
{
	if (!g_bCoreAvailable || g_cvEnabled == null || !g_cvEnabled.BoolValue)
	{
		return Plugin_Continue;
	}

	L4D2CN_Noise("player_disconnect received. name=%s reason=%s", playerName, reason);

	if (g_cvSuppressPlayerDisconnect != null && g_cvSuppressPlayerDisconnect.BoolValue)
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action L4D2Comm_OnPlayerNameChangeMessage(const char[] oldName, const char[] newName)
{
	if (!g_bCoreAvailable || g_cvEnabled == null || !g_cvEnabled.BoolValue)
	{
		return Plugin_Continue;
	}

	L4D2CN_Noise("player_changename received. old=%s new=%s", oldName, newName);

	if (g_cvSuppressNameChange != null && g_cvSuppressNameChange.BoolValue)
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action L4D2Comm_OnPlayerTeamMessage(const char[] playerName, L4DTeam team, bool disconnect)
{
	if (!g_bCoreAvailable || g_cvEnabled == null || !g_cvEnabled.BoolValue)
	{
		return Plugin_Continue;
	}

	L4D2CN_Noise("player_team received. name=%s team=%d disconnect=%d", playerName, team, disconnect);

	if (disconnect)
	{
		return Plugin_Continue;
	}

	if (g_cvSuppressPlayerTeam != null && g_cvSuppressPlayerTeam.BoolValue)
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action L4D2Comm_OnSayText2Message(const char[] msgKey, const char[] param1, const char[] param2, const char[] param3, const char[] param4, int firstTarget, int playersNum, bool reliable, bool init)
{
	if (!g_bCoreAvailable || g_cvEnabled == null || !g_cvEnabled.BoolValue)
	{
		return Plugin_Continue;
	}

	L4D2CN_Noise("SayText2 received. key=%s p1=%s p2=%s p3=%s p4=%s first=%d players=%d reliable=%d init=%d", msgKey, param1, param2, param3, param4, firstTarget, playersNum, reliable, init);

	if (g_cvSuppressNameChange != null && g_cvSuppressNameChange.BoolValue)
	{
		if (StrContains(msgKey, "Cstrike_Name_Change", false) != -1)
		{
			return Plugin_Handled;
		}
	}

	if (g_cvSuppressSourceModCvar != null && g_cvSuppressSourceModCvar.BoolValue)
	{
		if (IsSourceModCvarChangeMessage(msgKey, param1, param2, param3, param4))
		{
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

public Action L4D2Comm_OnTextMsgMessage(const char[] msgKey, const char[] param1, const char[] param2, const char[] param3, const char[] param4, int firstTarget, int playersNum, bool reliable, bool init)
{
	if (!g_bCoreAvailable || g_cvEnabled == null || !g_cvEnabled.BoolValue)
	{
		return Plugin_Continue;
	}

	L4D2CN_Noise("TextMsg received. key=%s p1=%s p2=%s p3=%s p4=%s first=%d players=%d reliable=%d init=%d", msgKey, param1, param2, param3, param4, firstTarget, playersNum, reliable, init);

	if (g_cvSuppressSourceModCvar != null && g_cvSuppressSourceModCvar.BoolValue)
	{
		if (IsSourceModCvarChangeMessage(msgKey, param1, param2, param3, param4))
		{
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

bool IsSourceModCvarChangeMessage(const char[] msgKey, const char[] param1, const char[] param2, const char[] param3, const char[] param4)
{
	return
		IsSourceModCvarChangeToken(msgKey)
		|| IsSourceModCvarChangeToken(param1)
		|| IsSourceModCvarChangeToken(param2)
		|| IsSourceModCvarChangeToken(param3)
		|| IsSourceModCvarChangeToken(param4);
}

bool IsSourceModCvarChangeToken(const char[] value)
{
	if (value[0] == '\0')
	{
		return false;
	}

	if (StrEqual(value, "Cvar changed", false))
	{
		return true;
	}

	if (StrContains(value, "[SM] Cvar \"", false) != -1)
	{
		return true;
	}

	if (StrContains(value, "Cvar \"", false) != -1)
	{
		if (StrContains(value, "changed to", false) != -1 || StrContains(value, "cambiada a", false) != -1)
		{
			return true;
		}
	}

	return false;
}

void L4D2CN_InitCommands()
{
	RegAdminCmd("sm_l4d2_chatnoise_status", Command_L4D2CN_Status, ADMFLAG_GENERIC, "Show L4D2 ChatNoise status.");
}

public Action Command_L4D2CN_Status(int client, int args)
{
	CReplyToCommand(
		client,
		"%s core=%d debug_mask=%d enabled=%d join=%d leave=%d team=%d server_cvar=%d name_change=%d",
		L4D2_COMMSUITE_CHATNOISE_PREFIX,
		g_bCoreAvailable,
		g_cvDebugMask != null ? g_cvDebugMask.IntValue : 0,
		g_cvEnabled != null ? g_cvEnabled.BoolValue : false,
		g_cvSuppressPlayerConnect != null ? g_cvSuppressPlayerConnect.BoolValue : false,
		g_cvSuppressPlayerDisconnect != null ? g_cvSuppressPlayerDisconnect.BoolValue : false,
		g_cvSuppressPlayerTeam != null ? g_cvSuppressPlayerTeam.BoolValue : false,
		g_cvSuppressServerCvar != null ? g_cvSuppressServerCvar.BoolValue : false,
		g_cvSuppressNameChange != null ? g_cvSuppressNameChange.BoolValue : false
	);
	CReplyToCommand(client, "%s sm_cvar_change=%d", L4D2_COMMSUITE_CHATNOISE_PREFIX, g_cvSuppressSourceModCvar != null ? g_cvSuppressSourceModCvar.BoolValue : false);
	return Plugin_Handled;
}
