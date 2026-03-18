#pragma semicolon 1
#pragma newdecls required

#include <colors>
#include <sourcemod>

#include <l4d2_commcore>
#include <l4d2_commsuite_shared>

enum L4D2CommDebugMask
{
	L4D2CommDebug_General = 1,
	L4D2CommDebug_Hook = 2,
	L4D2CommDebug_Noise = 4
};

ConVar g_cvL4D2Comm_DebugMask = null;
ConVar g_cvL4D2Comm_NoiseEnabled = null;
ConVar g_cvL4D2Comm_LogMode = null;

bool g_bL4D2Comm_CoreReady = false;
char g_sLogPath[PLATFORM_MAX_PATH];

Handle g_hL4D2Comm_FwdOnChatMessage = INVALID_HANDLE;
Handle g_hL4D2Comm_FwdOnChatMessagePost = INVALID_HANDLE;
Handle g_hL4D2Comm_FwdOnServerCvarMessage = INVALID_HANDLE;
Handle g_hL4D2Comm_FwdOnPlayerConnectMessage = INVALID_HANDLE;
Handle g_hL4D2Comm_FwdOnPlayerDisconnectMessage = INVALID_HANDLE;
Handle g_hL4D2Comm_FwdOnPlayerNameChangeMessage = INVALID_HANDLE;
Handle g_hL4D2Comm_FwdOnPlayerTeamMessage = INVALID_HANDLE;
Handle g_hL4D2Comm_FwdOnTextMsgMessage = INVALID_HANDLE;
Handle g_hL4D2Comm_FwdOnSayText2Message = INVALID_HANDLE;

#include "l4d2_commcore/helpers.sp"
#include "l4d2_commcore/noise.sp"
#include "l4d2_commcore/hooks.sp"

public Plugin myinfo =
{
	name = "L4D2 CommCore",
	author = "lechuga",
	description = "Core communication hooks and API for Left 4 Dead 2.",
	version = L4D2_COMMCORE_VERSION,
	url = "https://github.com/AoC-Gamers/L4D2-CommSuite"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int errMax)
{
	RegPluginLibrary(L4D2_COMMCORE_LIBRARY);
	L4D2Comm_RegisterNatives();
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_cvL4D2Comm_LogMode = L4D2CS_EnsureLogModeConVar();
	g_cvL4D2Comm_DebugMask = CreateConVar("l4d2_commcore_debug_mask", "0", "Debug bitmask. 1=general 2=hook 4=noise (all=7).", FCVAR_NONE, true, 0.0, true, 7.0);
	g_cvL4D2Comm_NoiseEnabled = CreateConVar("l4d2_commcore_noise_enabled", "1", "Enable communication noise filtering hooks.", FCVAR_NONE, true, 0.0, true, 1.0);
	L4D2CS_BuildLogPath("l4d2_commcore.log", g_sLogPath, sizeof(g_sLogPath));

	L4D2Comm_InitHooks();
	L4D2Comm_InitCommands();
	L4D2Comm_SetCoreReady(true);
	L4D2CS_NormalLogToFileEx(g_cvL4D2Comm_LogMode, L4D2_COMMSUITE_COMMCORE_LOG_PREFIX, "startup", "Plugin started. version=%s", L4D2_COMMCORE_VERSION);
	L4D2Comm_Debug("Plugin started. version=%s", L4D2_COMMCORE_VERSION);

	L4D2CS_EnsureAutoExecFolder();
	AutoExecConfig(true, "l4d2_commcore", L4D2_COMMSUITE_AUTOEXEC_FOLDER);
}

void L4D2Comm_SetCoreReady(bool ready)
{
	g_bL4D2Comm_CoreReady = ready;
}

void L4D2Comm_RegisterNatives()
{
	if (g_hL4D2Comm_FwdOnChatMessage == INVALID_HANDLE)
	{
		g_hL4D2Comm_FwdOnChatMessage = CreateGlobalForward("L4D2Comm_OnChatMessage", ET_Hook, Param_Cell, Param_Cell, Param_String);
	}

	if (g_hL4D2Comm_FwdOnChatMessagePost == INVALID_HANDLE)
	{
		g_hL4D2Comm_FwdOnChatMessagePost = CreateGlobalForward("L4D2Comm_OnChatMessage_Post", ET_Ignore, Param_Cell, Param_Cell, Param_String);
	}

	if (g_hL4D2Comm_FwdOnServerCvarMessage == INVALID_HANDLE)
	{
		g_hL4D2Comm_FwdOnServerCvarMessage = CreateGlobalForward("L4D2Comm_OnServerCvarMessage", ET_Hook, Param_String, Param_String);
	}

	if (g_hL4D2Comm_FwdOnPlayerConnectMessage == INVALID_HANDLE)
	{
		g_hL4D2Comm_FwdOnPlayerConnectMessage = CreateGlobalForward("L4D2Comm_OnPlayerConnectMessage", ET_Hook, Param_String);
	}

	if (g_hL4D2Comm_FwdOnPlayerDisconnectMessage == INVALID_HANDLE)
	{
		g_hL4D2Comm_FwdOnPlayerDisconnectMessage = CreateGlobalForward("L4D2Comm_OnPlayerDisconnectMessage", ET_Hook, Param_String, Param_String);
	}

	if (g_hL4D2Comm_FwdOnPlayerNameChangeMessage == INVALID_HANDLE)
	{
		g_hL4D2Comm_FwdOnPlayerNameChangeMessage = CreateGlobalForward("L4D2Comm_OnPlayerNameChangeMessage", ET_Hook, Param_String, Param_String);
	}

	if (g_hL4D2Comm_FwdOnPlayerTeamMessage == INVALID_HANDLE)
	{
		g_hL4D2Comm_FwdOnPlayerTeamMessage = CreateGlobalForward("L4D2Comm_OnPlayerTeamMessage", ET_Hook, Param_String, Param_Cell, Param_Cell);
	}

	if (g_hL4D2Comm_FwdOnTextMsgMessage == INVALID_HANDLE)
	{
		g_hL4D2Comm_FwdOnTextMsgMessage = CreateGlobalForward("L4D2Comm_OnTextMsgMessage", ET_Hook, Param_String, Param_String, Param_String, Param_String, Param_String, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	}

	if (g_hL4D2Comm_FwdOnSayText2Message == INVALID_HANDLE)
	{
		g_hL4D2Comm_FwdOnSayText2Message = CreateGlobalForward("L4D2Comm_OnSayText2Message", ET_Hook, Param_String, Param_String, Param_String, Param_String, Param_String, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	}

	CreateNative("L4D2Comm_IsCoreReady", Native_L4D2CommIsCoreReady);
}

public any Native_L4D2CommIsCoreReady(Handle plugin, int numParams)
{
	return g_bL4D2Comm_CoreReady;
}

void L4D2Comm_InitCommands()
{
	RegAdminCmd("sm_l4d2_commcore_status", Command_L4D2CommStatus, ADMFLAG_GENERIC, "Show L4D2 CommCore status.");
}

public Action Command_L4D2CommStatus(int client, int args)
{
	CReplyToCommand(
		client,
		"%s ready=%d debug_mask=%d noise=%d",
		L4D2_COMMSUITE_COMMCORE_PREFIX,
		g_bL4D2Comm_CoreReady,
		g_cvL4D2Comm_DebugMask != null ? g_cvL4D2Comm_DebugMask.IntValue : 0,
		g_cvL4D2Comm_NoiseEnabled != null ? g_cvL4D2Comm_NoiseEnabled.BoolValue : false
	);
	return Plugin_Handled;
}
