#if defined _l4d2_commsuite_shared_included
	#endinput
#endif
#define _l4d2_commsuite_shared_included

#include <left4dhooks_stocks>

#define L4D2_COMMSUITE_AUTOEXEC_FOLDER "sourcemod/l4d2_commsuite"
#define L4D2_COMMSUITE_AUTOEXEC_FOLDER_PATH "../../cfg/sourcemod/l4d2_commsuite"
#define L4D2_COMMSUITE_SM_LOGS_FOLDER "logs"
#define L4D2_COMMSUITE_LOG_FOLDER_PATH "logs/l4d2_commsuite"
#define L4D2_COMMSUITE_BASECOMM_LIBRARY "basecomm"
#define L4D2_COMMSUITE_SOURCECOMMS_LIBRARY "sourcecomms++"
#define L4D2_COMMSUITE_BANSYSTEM_COMM_LIBRARY "bansystem_comm"

enum L4D2CommSuiteLogMode
{
	L4D2CommSuiteLogMode_Off = 0,
	L4D2CommSuiteLogMode_Normal,
	L4D2CommSuiteLogMode_Debug
}

#define L4D2_COMMSUITE_COMMCORE_PREFIX "{olive}[L4D2 CommCore]{default}"
#define L4D2_COMMSUITE_COMMCORE_LOG_PREFIX "[L4D2 CommCore]"
#define L4D2_COMMSUITE_COMMGUARD_PREFIX "{olive}[L4D2 CommGuard]{default}"
#define L4D2_COMMSUITE_COMMGUARD_LOG_PREFIX "[L4D2 CommGuard]"
#define L4D2_COMMSUITE_COMMRELAY_PREFIX "{olive}[L4D2 CommRelay]{default}"
#define L4D2_COMMSUITE_COMMRELAY_LOG_PREFIX "[L4D2 CommRelay]"
#define L4D2_COMMSUITE_CHATNOISE_PREFIX "{olive}[L4D2 ChatNoise]{default}"
#define L4D2_COMMSUITE_CHATNOISE_LOG_PREFIX "[L4D2 ChatNoise]"
#define L4D2_COMMSUITE_CHATLOG_PREFIX "{olive}[L4D2 ChatLog]{default}"
#define L4D2_COMMSUITE_CHATLOG_LOG_PREFIX "[L4D2 ChatLog]"

stock bool IsHumanClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client);
}

stock bool L4D2CS_IsValidClientIndex(int client)
{
	return client > 0 && client <= MaxClients;
}

stock bool L4D2CS_IsConnectedClient(int client)
{
	return L4D2CS_IsValidClientIndex(client) && IsClientConnected(client);
}

stock void L4D2CS_GetTeamLabel(L4DTeam team, char[] buffer, int maxlen)
{
	switch (team)
	{
		case L4DTeam_Spectator:
		{
			strcopy(buffer, maxlen, "Spectator");
		}
		case L4DTeam_Survivor:
		{
			strcopy(buffer, maxlen, "Survivor");
		}
		case L4DTeam_Infected:
		{
			strcopy(buffer, maxlen, "Infected");
		}
		default:
		{
			strcopy(buffer, maxlen, "Unknown");
		}
	}
}

stock int L4D2CS_GetCommandUserId(int client)
{
	if (L4D2CS_IsValidClientIndex(client))
	{
		return GetClientUserId(client);
	}

	return 0;
}

stock int L4D2CS_ResolveCommandClient(int userId)
{
	if (userId == 0)
	{
		return 0;
	}

	return GetClientOfUserId(userId);
}

stock void L4D2CS_PrintConsoleOrServer(int userId, const char[] line)
{
	int client = L4D2CS_ResolveCommandClient(userId);

	if (client > 0)
	{
		PrintToConsole(client, "%s", line);
		return;
	}

	PrintToServer("%s", line);
}

stock ConVar L4D2CS_FindOrCreatePluginLogModeConVar(const char[] conVarName, const char[] description)
{
	ConVar cvLogMode = CreateConVar(conVarName, "0", description, FCVAR_NONE, true, 0.0, true, 2.0);
	if (cvLogMode != null)
	{
		return cvLogMode;
	}

	return FindConVar(conVarName);
}

stock bool L4D2CS_IsNormalLogMode(ConVar cvLogMode)
{
	return (cvLogMode != null && cvLogMode.IntValue == view_as<int>(L4D2CommSuiteLogMode_Normal));
}

stock bool L4D2CS_IsDebugLogMode(ConVar cvLogMode)
{
	return (cvLogMode != null && cvLogMode.IntValue == view_as<int>(L4D2CommSuiteLogMode_Debug));
}

stock bool L4D2CS_DebugMaskEnabled(ConVar cvLogMode, ConVar cvDebugMask, int bit)
{
	if (!L4D2CS_IsDebugLogMode(cvLogMode) || cvDebugMask == null)
	{
		return false;
	}

	return ((cvDebugMask.IntValue & bit) != 0);
}

stock void L4D2CS_EnsureAutoExecFolder()
{
	static bool s_bEnsured;
	if (s_bEnsured)
	{
		return;
	}

	char folderPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, folderPath, sizeof(folderPath), L4D2_COMMSUITE_AUTOEXEC_FOLDER_PATH);
	if (!DirExists(folderPath))
	{
		CreateDirectory(folderPath);
	}

	s_bEnsured = true;
}

stock void L4D2CS_EnsureSMLogsFolder()
{
	static bool s_bEnsured;
	if (s_bEnsured)
	{
		return;
	}

	char logsPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, logsPath, sizeof(logsPath), L4D2_COMMSUITE_SM_LOGS_FOLDER);
	if (!DirExists(logsPath))
	{
		CreateDirectory(logsPath, 511);
	}

	s_bEnsured = DirExists(logsPath);
}

stock void L4D2CS_EnsureLogFolder(ConVar cvLogMode)
{
	static bool s_bEnsured;
	if (s_bEnsured)
	{
		return;
	}

	L4D2CS_EnsureSMLogsFolder();

	if (!L4D2CS_IsDebugLogMode(cvLogMode))
	{
		return;
	}

	char folderPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, folderPath, sizeof(folderPath), L4D2_COMMSUITE_LOG_FOLDER_PATH);
	if (!DirExists(folderPath))
	{
		CreateDirectory(folderPath, 511);
	}

	s_bEnsured = DirExists(folderPath);
}

stock void L4D2CS_BuildLogPath(ConVar cvLogMode, const char[] fileName, char[] buffer, int maxlen)
{
	L4D2CS_EnsureLogFolder(cvLogMode);
	BuildPath(Path_SM, buffer, maxlen, "%s/%s", L4D2_COMMSUITE_LOG_FOLDER_PATH, fileName);
}

stock void L4D2CS_EnsureDebugLogPathReady(ConVar cvLogMode)
{
	L4D2CS_EnsureLogFolder(cvLogMode);
}

stock void L4D2CS_BuildNormalLogPath(const char[] fileName, char[] buffer, int maxlen)
{
	L4D2CS_EnsureSMLogsFolder();
	BuildPath(Path_SM, buffer, maxlen, "%s/%s", L4D2_COMMSUITE_SM_LOGS_FOLDER, fileName);
}

stock void L4D2CS_NormalLogToFileEx(ConVar cvLogMode, const char[] fileName, const char[] prefix, const char[] tag, const char[] format, any ...)
{
	if (!L4D2CS_IsNormalLogMode(cvLogMode))
	{
		return;
	}

	char logPath[PLATFORM_MAX_PATH];
	L4D2CS_BuildNormalLogPath(fileName, logPath, sizeof(logPath));

	static char buffer[1024];
	VFormat(buffer, sizeof(buffer), format, 5);

	if (tag[0] != '\0')
	{
		LogToFileEx(logPath, "%s[%s] %s", prefix, tag, buffer);
	}
	else
	{
		LogToFileEx(logPath, "%s %s", prefix, buffer);
	}
}
