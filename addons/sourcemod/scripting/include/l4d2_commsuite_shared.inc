#if defined _l4d2_commsuite_shared_included
	#endinput
#endif
#define _l4d2_commsuite_shared_included

#define L4D2_COMMSUITE_AUTOEXEC_FOLDER "sourcemod/l4d2_commsuite"
#define L4D2_COMMSUITE_AUTOEXEC_FOLDER_PATH "../../cfg/sourcemod/l4d2_commsuite"
#define L4D2_COMMSUITE_LOG_FOLDER_PATH "logs/l4d2_commsuite"
#define L4D2_COMMSUITE_BASECOMM_LIBRARY "basecomm"
#define L4D2_COMMSUITE_SOURCECOMMS_LIBRARY "sourcecomms++"
#define L4D2_COMMSUITE_BANSYSTEM_COMM_LIBRARY "bansystem_comm"

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

stock void L4D2CS_EnsureLogFolder()
{
	static bool s_bEnsured;
	if (s_bEnsured)
	{
		return;
	}

	char folderPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, folderPath, sizeof(folderPath), L4D2_COMMSUITE_LOG_FOLDER_PATH);
	if (!DirExists(folderPath))
	{
		CreateDirectory(folderPath);
	}

	s_bEnsured = true;
}

stock void L4D2CS_BuildLogPath(const char[] fileName, char[] buffer, int maxlen)
{
	L4D2CS_EnsureLogFolder();
	BuildPath(Path_SM, buffer, maxlen, "%s/%s", L4D2_COMMSUITE_LOG_FOLDER_PATH, fileName);
}
