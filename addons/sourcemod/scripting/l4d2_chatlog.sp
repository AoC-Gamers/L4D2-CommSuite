#pragma semicolon 1
#pragma newdecls required

#include <left4dhooks_stocks>
#include <colors>
#include <sourcemod>
#include <geoip>
#include <l4d2_commcore>
#include <l4d2_commsuite_shared>

enum DebugMask
{
	Debug_General = 1,
	Debug_Write = 2,
	Debug_Lifecycle = 4,
	Debug_SQL = 8
};

#define L4D2_CHATLOG_VERSION "0.2.0"
#define L4D2_CHATLOG_SQL_TABLE "l4d2_chatlog_joins"

ConVar g_cvDebugMask = null;
ConVar g_cvEnabled = null;
ConVar g_cvLogPublic = null;
ConVar g_cvLogTeam = null;
ConVar g_cvLogBlocked = null;
ConVar g_cvLogConsole = null;
ConVar g_cvLogFakeClients = null;
ConVar g_cvLogConnect = null;
ConVar g_cvLogDisconnect = null;
ConVar g_cvLogNameChange = null;
ConVar g_cvLogPlayerTeam = null;
ConVar g_cvDetail = null;
ConVar g_cvJoinAudit = null;
ConVar g_cvFileNameFormat = null;
ConVar g_cvSqlEnabled = null;
ConVar g_cvSqlConfig = null;
ConVar g_cvSqlServerId = null;
ConVar g_cvSqlDefaultHistoryLimit = null;
ConVar g_cvSqlDefaultRelatedDays = null;
ConVar g_cvSqlDefaultRelatedMinShared = null;
ConVar g_cvLogMode = null;

bool g_bLateLoad = false;
bool g_bCoreAvailable = false;
bool g_bMapBannerPending = true;
bool g_bDbReady = false;
bool g_bDbConnecting = false;
bool g_bJoinHandled[MAXPLAYERS + 1];
bool g_bJoinSqlQueued[MAXPLAYERS + 1];

char g_sCurrentMap[PLATFORM_MAX_PATH];
char g_sCurrentStamp[32];
char g_sChatFile[PLATFORM_MAX_PATH];
char g_sJoinFile[PLATFORM_MAX_PATH];
char g_sDbConfig[64];
char g_sLogPath[PLATFORM_MAX_PATH];

Database g_db = null;

public Plugin myinfo =
{
	name = "L4D2 ChatLog",
	author = "lechuga",
	description = "Audit logging satellite for L4D2 CommCore.",
	version = L4D2_CHATLOG_VERSION,
	url = "https://github.com/AoC-Gamers/L4D2-CommSuite"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int errMax)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	g_bCoreAvailable = LibraryExists(L4D2_COMMCORE_LIBRARY);
	LogFormatted(Debug_General, "debug", "OnAllPluginsLoaded. core=%d", g_bCoreAvailable);
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, L4D2_COMMCORE_LIBRARY))
	{
		g_bCoreAvailable = true;
		LogFormatted(Debug_General, "debug", "Library added: %s", name);
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, L4D2_COMMCORE_LIBRARY))
	{
		g_bCoreAvailable = false;
		LogFormatted(Debug_General, "debug", "Library removed: %s", name);
	}
}

public void OnPluginStart()
{
	g_cvLogMode = L4D2CS_EnsureLogModeConVar();
	g_cvDebugMask = CreateConVar("l4d2_chatlog_debug_mask", "0", "Debug bitmask. 1=general 2=write 4=lifecycle 8=sql (all=15).", FCVAR_NONE, true, 0.0, true, 15.0);
	g_cvEnabled = CreateConVar("l4d2_chatlog_enabled", "1", "Enable chat audit logging.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvLogPublic = CreateConVar("l4d2_chatlog_log_public", "1", "Log public chat messages.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvLogTeam = CreateConVar("l4d2_chatlog_log_team", "1", "Log team chat messages.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvLogBlocked = CreateConVar("l4d2_chatlog_log_blocked", "0", "Log blocked chat attempts.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvLogConsole = CreateConVar("l4d2_chatlog_log_console", "1", "Log console chat commands.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvLogFakeClients = CreateConVar("l4d2_chatlog_log_fakeclients", "0", "Log fake client chat and lifecycle entries.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvLogConnect = CreateConVar("l4d2_chatlog_log_connect", "1", "Log client joins.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvLogDisconnect = CreateConVar("l4d2_chatlog_log_disconnect", "1", "Log client disconnects.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvLogNameChange = CreateConVar("l4d2_chatlog_log_name_change", "1", "Log player name changes.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvLogPlayerTeam = CreateConVar("l4d2_chatlog_log_player_team", "0", "Log player team changes.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvDetail = CreateConVar("l4d2_chatlog_detail", "1", "Include extended identity details in lifecycle and join records.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvJoinAudit = CreateConVar("l4d2_chatlog_join_audit", "1", "Write join records to logs/chats/join.log.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvFileNameFormat = CreateConVar("l4d2_chatlog_filename_format", "%Y%m%d", "Date format used for logs/chats/chat_<date>.log.", FCVAR_NONE);
	g_cvSqlEnabled = CreateConVar("l4d2_chatlog_sql_enabled", "0", "Enable async MySQL join audit logging.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvSqlConfig = CreateConVar("l4d2_chatlog_sql_config", "default", "Databases.cfg entry used for join audit queries.", FCVAR_NONE);
	g_cvSqlServerId = CreateConVar("l4d2_chatlog_sql_server_id", "", "Logical server identifier stored with join audit rows.", FCVAR_NONE);
	g_cvSqlDefaultHistoryLimit = CreateConVar("l4d2_chatlog_sql_default_history_limit", "25", "Default result limit for join history queries.", FCVAR_NONE, true, 1.0, true, 200.0);
	g_cvSqlDefaultRelatedDays = CreateConVar("l4d2_chatlog_sql_default_related_days", "30", "Default day window for related-account queries.", FCVAR_NONE, true, 1.0, true, 3650.0);
	g_cvSqlDefaultRelatedMinShared = CreateConVar("l4d2_chatlog_sql_default_related_min_shared", "2", "Default minimum shared joins per IP for related-account queries.", FCVAR_NONE, true, 1.0, true, 1000.0);
	L4D2CS_BuildLogPath("l4d2_chatlog.log", g_sLogPath, sizeof(g_sLogPath));

	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);

	InitCommands();
	RefreshMapState();
	LogFormatted(Debug_General, "debug", "Plugin started. version=%s", L4D2_CHATLOG_VERSION);

	L4D2CS_EnsureAutoExecFolder();
	AutoExecConfig(true, "l4d2_chatlog", L4D2_COMMSUITE_AUTOEXEC_FOLDER);

	if (!g_bLateLoad)
	{
		return;
	}

	for (int client = 1; client <= MaxClients; client++)
	{
		if (!ShouldLogConnect(client))
		{
			continue;
		}

		g_bJoinHandled[client] = true;
		g_bJoinSqlQueued[client] = false;
	}
}

public void OnConfigsExecuted()
{
	RefreshSqlConnection(false);
}

public void OnPluginEnd()
{
	CloseDatabase();
}

public void OnClientDisconnect(int client)
{
	g_bJoinHandled[client] = false;
	g_bJoinSqlQueued[client] = false;
}

public void OnMapStart()
{
	RefreshMapState();
	WriteMapBannerIfNeeded();
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(client))
	{
		return;
	}

	L4DTeam oldTeam = view_as<L4DTeam>(event.GetInt("oldteam"));
	L4DTeam team = view_as<L4DTeam>(event.GetInt("team"));
	bool isDisconnect = event.GetBool("disconnect");

	if (isDisconnect && team == L4DTeam_Unassigned)
	{
		g_bJoinHandled[client] = false;
		g_bJoinSqlQueued[client] = false;
		return;
	}

	if (!ShouldLogConnect(client))
	{
		return;
	}

	if (oldTeam != L4DTeam_Unassigned || team == L4DTeam_Unassigned || g_bJoinHandled[client])
	{
		return;
	}

	g_bJoinHandled[client] = true;

	char line[1024];
	FormatLifecycleLine(client, "JOIN", "", line, sizeof(line));
	WriteMessage(line);

	if (g_cvJoinAudit != null && g_cvJoinAudit.BoolValue)
	{
		char joinLine[1024];
		FormatJoinAuditLine(client, joinLine, sizeof(joinLine));
		WriteJoinMessage(joinLine);
	}

	QueueJoinInsert(client);
	LogFormatted(Debug_Lifecycle, "lifecycle", "Logged client join. client=%d", client);
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_cvEnabled.BoolValue || g_cvLogDisconnect == null || !g_cvLogDisconnect.BoolValue || dontBroadcast)
	{
		return Plugin_Continue;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client <= 0 || client > MaxClients)
	{
		return Plugin_Continue;
	}

	if (IsFakeClient(client) && (g_cvLogFakeClients == null || !g_cvLogFakeClients.BoolValue))
	{
		return Plugin_Continue;
	}

	char reason[256];
	char line[1024];
	event.GetString("reason", reason, sizeof(reason));
	FormatLifecycleLine(client, "LEAVE", reason, line, sizeof(line));
	WriteMessage(line);
	LogFormatted(Debug_Lifecycle, "lifecycle", "Logged client disconnect. client=%d reason=%s", client, reason);
	return Plugin_Continue;
}

public void L4D2Comm_OnChatMessage_Rendered_Post(int client, L4D2CommChannel channel, const char[] prefix, const char[] name, const char[] text)
{
	if (!g_bCoreAvailable || g_cvEnabled == null || !g_cvEnabled.BoolValue)
	{
		return;
	}

	if (!ShouldLogChat(client, channel))
	{
		return;
	}

	if (client > 0 && IsClientInGame(client) && IsFakeClient(client) && (g_cvLogFakeClients == null || !g_cvLogFakeClients.BoolValue))
	{
		return;
	}

	char line[1024];
	FormatRenderedChatLine(client, channel, prefix, name, text, line, sizeof(line));
	WriteMessage(line);
	LogFormatted(Debug_Write, "write", "Logged chat. client=%d channel=%d prefix=%s name=%s text=%s", client, channel, prefix, name, text);
}

public void L4D2Comm_OnChatMessage_Blocked(int client, L4D2CommChannel channel, const char[] text)
{
	if (!g_bCoreAvailable || g_cvEnabled == null || !g_cvEnabled.BoolValue)
	{
		return;
	}

	if (!ShouldLogBlockedChat(client, channel))
	{
		return;
	}

	if (client > 0 && IsClientInGame(client) && IsFakeClient(client) && (g_cvLogFakeClients == null || !g_cvLogFakeClients.BoolValue))
	{
		return;
	}

	char line[1024];
	FormatBlockedChatLine(client, channel, text, line, sizeof(line));
	WriteMessage(line);
	LogFormatted(Debug_Write, "write", "Logged blocked chat. client=%d channel=%d text=%s", client, channel, text);
}

public Action L4D2Comm_OnPlayerNameChangeMessage(const char[] oldName, const char[] newName)
{
	if (!g_bCoreAvailable || g_cvEnabled == null || !g_cvEnabled.BoolValue)
	{
		return Plugin_Continue;
	}

	if (g_cvLogNameChange == null || !g_cvLogNameChange.BoolValue)
	{
		return Plugin_Continue;
	}

	char timestamp[64];
	char line[1024];
	GetTimestamp(timestamp, sizeof(timestamp));
	FormatEx(line, sizeof(line), "[%s] [NAME] %s -> %s", timestamp, oldName, newName);
	WriteMessage(line);
	LogFormatted(Debug_Lifecycle, "lifecycle", "Logged name change. old=%s new=%s", oldName, newName);
	return Plugin_Continue;
}

public Action L4D2Comm_OnPlayerTeamMessage(const char[] playerName, L4DTeam team, bool disconnect)
{
	if (!g_bCoreAvailable || g_cvEnabled == null || !g_cvEnabled.BoolValue || disconnect)
	{
		return Plugin_Continue;
	}

	if (g_cvLogPlayerTeam == null || !g_cvLogPlayerTeam.BoolValue)
	{
		return Plugin_Continue;
	}

	char timestamp[64];
	char teamLabel[16];
	char line[1024];
	GetTimestamp(timestamp, sizeof(timestamp));
	L4D2CS_GetTeamLabel(team, teamLabel, sizeof(teamLabel));
	FormatEx(line, sizeof(line), "[%s] [TEAM] %s -> %s", timestamp, playerName, teamLabel);
	WriteMessage(line);
	LogFormatted(Debug_Lifecycle, "lifecycle", "Logged player team change. name=%s team=%d", playerName, team);
	return Plugin_Continue;
}

bool DebugEnabled(DebugMask bit)
{
	return L4D2CS_DebugMaskEnabled(g_cvLogMode, g_cvDebugMask, view_as<int>(bit));
}

void LogFormatted(DebugMask bit, const char[] tag, const char[] format, any ...)
{
	if (!DebugEnabled(bit))
	{
		return;
	}

	static char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 4);
	L4D2CS_EnsureDebugLogPathReady();
	LogToFileEx(g_sLogPath, "%s[%s] %s", L4D2_COMMSUITE_CHATLOG_LOG_PREFIX, tag, buffer);
}

bool IsValidClient(int client)
{
	return L4D2CS_IsConnectedClient(client);
}

void ReplyCommand(int client, const char[] format, any ...)
{
	static char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 3);
	ReplaceString(buffer, sizeof(buffer), "[L4D2 ChatLog]", L4D2_COMMSUITE_CHATLOG_PREFIX, false);
	CReplyToCommand(client, "%s", buffer);
}

void ReplyAsync(int userId, const char[] format, any ...)
{
	static char buffer[512];
	int client = L4D2CS_ResolveCommandClient(userId);
	VFormat(buffer, sizeof(buffer), format, 2);
	ReplaceString(buffer, sizeof(buffer), "[L4D2 ChatLog]", L4D2_COMMSUITE_CHATLOG_PREFIX, false);
	CReplyToCommand(client, "%s", buffer);
}

void PrintQueryLine(int userId, const char[] format, any ...)
{
	static char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 2);
	L4D2CS_PrintConsoleOrServer(userId, buffer);
}

bool IsNumericString(const char[] value)
{
	int length = strlen(value);
	if (length == 0)
	{
		return false;
	}

	for (int i = 0; i < length; i++)
	{
		if (!IsCharNumeric(value[i]))
		{
			return false;
		}
	}

	return true;
}

bool IsLikelyIpAddress(const char[] value)
{
	int length = strlen(value);
	if (length < 3)
	{
		return false;
	}

	bool hasSeparator = false;
	for (int i = 0; i < length; i++)
	{
		char c = value[i];
		if (IsCharNumeric(c))
		{
			continue;
		}

		if (c == '.' || c == ':')
		{
			hasSeparator = true;
			continue;
		}

		return false;
	}

	return hasSeparator;
}

void GetOptionalServerFilter(int args, int argIndex, char[] buffer, int maxlen)
{
	buffer[0] = '\0';

	if (args < argIndex)
	{
		return;
	}

	GetCmdArg(argIndex, buffer, maxlen);
	TrimString(buffer);
	StripQuotes(buffer);

	if (StrEqual(buffer, "*", false) || StrEqual(buffer, "all", false) || StrEqual(buffer, "any", false))
	{
		buffer[0] = '\0';
	}
}

void CloseDatabase()
{
	g_bDbReady = false;
	g_bDbConnecting = false;

	if (g_db != null)
	{
		delete g_db;
		g_db = null;
	}
}

bool CanUseDatabase()
{
	return g_cvSqlEnabled != null
		&& g_cvSqlEnabled.BoolValue
		&& g_db != null
		&& g_bDbReady;
}

void RefreshSqlConnection(bool force)
{
	if (g_cvSqlEnabled == null || !g_cvSqlEnabled.BoolValue)
	{
		if (force || g_db != null || g_bDbReady || g_bDbConnecting)
		{
			LogFormatted(Debug_SQL, "sql", "SQL disabled. closing current connection state.");
			CloseDatabase();
		}
		return;
	}

	char configName[64];
	g_cvSqlConfig.GetString(configName, sizeof(configName));

	if (!SQL_CheckConfig(configName))
	{
		LogFormatted(Debug_SQL, "sql", "SQL config not found: %s", configName);
		L4D2CS_NormalLogToFileEx(g_cvLogMode, L4D2_COMMSUITE_CHATLOG_LOG_PREFIX, "database", "config=%s action=config_missing", configName);
		CloseDatabase();
		return;
	}

	if (!force && (g_bDbReady || g_bDbConnecting) && StrEqual(configName, g_sDbConfig))
	{
		return;
	}

	CloseDatabase();
	strcopy(g_sDbConfig, sizeof(g_sDbConfig), configName);
	g_bDbConnecting = true;
	LogFormatted(Debug_SQL, "sql", "Starting SQL connection. config=%s", configName);
	Database.Connect(OnDatabaseConnected, configName);
}

public void OnDatabaseConnected(Database db, const char[] error, any data)
{
	g_bDbConnecting = false;

	if (db == null)
	{
		g_bDbReady = false;
		L4D2CS_NormalLogToFileEx(g_cvLogMode, L4D2_COMMSUITE_CHATLOG_LOG_PREFIX, "database", "config=%s action=connect_failed error=%s", g_sDbConfig, error);
		LogFormatted(Debug_SQL, "sql", "SQL connection failed. config=%s error=%s", g_sDbConfig, error);
		return;
	}

	if (error[0] != '\0')
	{
		g_bDbReady = false;
		L4D2CS_NormalLogToFileEx(g_cvLogMode, L4D2_COMMSUITE_CHATLOG_LOG_PREFIX, "database", "config=%s action=connect_failed error=%s", g_sDbConfig, error);
		LogFormatted(Debug_SQL, "sql", "SQL connection returned error. config=%s error=%s", g_sDbConfig, error);
		delete db;
		return;
	}

	g_db = db;
	g_bDbReady = false;
	LogFormatted(Debug_SQL, "sql", "SQL connection established. config=%s", g_sDbConfig);

	DBDriver driver = g_db.Driver;
	if (driver == null)
	{
		LogFormatted(Debug_SQL, "sql", "Database driver is null. closing connection.");
		L4D2CS_NormalLogToFileEx(g_cvLogMode, L4D2_COMMSUITE_CHATLOG_LOG_PREFIX, "database", "config=%s action=driver_missing", g_sDbConfig);
		CloseDatabase();
		return;
	}

	char driverName[64];
	driver.GetIdentifier(driverName, sizeof(driverName));
	LogFormatted(Debug_SQL, "sql", "Database driver detected: %s", driverName);

	if (!StrEqual(driverName, "mysql", false))
	{
		LogFormatted(Debug_SQL, "sql", "Unsupported SQL driver for chatlog join audit: %s", driverName);
		L4D2CS_NormalLogToFileEx(g_cvLogMode, L4D2_COMMSUITE_CHATLOG_LOG_PREFIX, "database", "config=%s action=driver_unsupported driver=%s", g_sDbConfig, driverName);
		CloseDatabase();
		return;
	}

	g_db.SetCharset("utf8");

	char query[256];
	int iLen = 0;
	iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "SHOW TABLES LIKE '%s';", L4D2_CHATLOG_SQL_TABLE);
	LogFormatted(Debug_SQL, "sql", "Queueing schema validation query: %s", query);
	g_db.Query(OnSchemaValidated, query);
}

public void OnSchemaValidated(Database db, DBResultSet results, const char[] error, any data)
{
	if (db == null)
	{
		LogFormatted(Debug_SQL, "sql", "Schema validation returned a null database handle.");
		return;
	}

	if (error[0] != '\0')
	{
		g_bDbReady = false;
		L4D2CS_NormalLogToFileEx(g_cvLogMode, L4D2_COMMSUITE_CHATLOG_LOG_PREFIX, "database", "config=%s action=schema_failed error=%s", g_sDbConfig, error);
		LogFormatted(Debug_SQL, "sql", "Schema validation failed. error=%s", error);
		delete results;
		return;
	}

	if (results == null)
	{
		g_bDbReady = false;
		L4D2CS_NormalLogToFileEx(g_cvLogMode, L4D2_COMMSUITE_CHATLOG_LOG_PREFIX, "database", "config=%s action=schema_failed error=null_result", g_sDbConfig);
		LogFormatted(Debug_SQL, "sql", "Schema validation failed with null result and no error text.");
		return;
	}

	g_bDbReady = results.FetchRow();
	delete results;
	LogFormatted(Debug_SQL, "sql", "Schema validation completed. config=%s ready=%d", g_sDbConfig, g_bDbReady);

	if (g_bDbReady)
	{
		QueueConnectedJoinInserts();
	}
}

void GetSqlServerId(char[] buffer, int maxlen)
{
	if (g_cvSqlServerId != null)
	{
		g_cvSqlServerId.GetString(buffer, maxlen);
		return;
	}

	buffer[0] = '\0';
}

void QueueJoinInsert(int client)
{
	if (!ShouldLogConnect(client))
	{
		return;
	}

	if (g_bJoinSqlQueued[client])
	{
		return;
	}

	if (!CanUseDatabase())
	{
		LogFormatted(Debug_SQL, "sql", "Skipped join insert because SQL backend is not ready. client=%d connecting=%d ready=%d db=%d", client, g_bDbConnecting, g_bDbReady, g_db != null);
		return;
	}

	char serverId[64];
	char playerName[128];
	char steam2[32];
	char steam64[32];
	char ipAddress[32];
	char country[64];
	char safeServerId[129];
	char safePlayerName[257];
	char safeSteam64[65];
	char safeIpAddress[65];
	char safeCountry[129];
	char query[1024];

	int accountId = GetSteamAccountID(client);
	GetSqlServerId(serverId, sizeof(serverId));
	GetClientName(client, playerName, sizeof(playerName));
	GetIdentityFields(client, steam2, sizeof(steam2), steam64, sizeof(steam64), ipAddress, sizeof(ipAddress), country, sizeof(country));
	g_db.Escape(serverId, safeServerId, sizeof(safeServerId));
	g_db.Escape(playerName, safePlayerName, sizeof(safePlayerName));
	g_db.Escape(steam64, safeSteam64, sizeof(safeSteam64));
	g_db.Escape(ipAddress, safeIpAddress, sizeof(safeIpAddress));
	g_db.Escape(country, safeCountry, sizeof(safeCountry));

	int iLen = 0;
	iLen += g_db.Format(
		query[iLen],
		sizeof(query) - iLen,
		"INSERT INTO `%s` (`joined_at`, `server_id`, `player_name`, `steamid64`, `accountid`, `ip_address`, `country`) VALUES (NOW(), ",
		L4D2_CHATLOG_SQL_TABLE
	);
	iLen += g_db.Format(
		query[iLen],
		sizeof(query) - iLen,
		"'%s', '%s', '%s', %d, '%s', '%s');",
		safeServerId,
		safePlayerName,
		safeSteam64,
		accountId,
		safeIpAddress,
		safeCountry
	);

	g_bJoinSqlQueued[client] = true;
	LogFormatted(Debug_SQL, "sql", "Queueing join insert. client=%d accountid=%d steamid64=%s", client, accountId, steam64);
	g_db.Query(OnJoinInsertCompleted, query, GetClientUserId(client));
}

public void OnJoinInsertCompleted(Database db, DBResultSet results, const char[] error, any data)
{
	int userId = data;
	int client = L4D2CS_ResolveCommandClient(userId);

	if (db == null)
	{
		LogFormatted(Debug_SQL, "sql", "Join insert callback returned a null database handle. userid=%d", userId);
		return;
	}

	if (error[0] != '\0')
	{
		if (L4D2CS_IsValidClientIndex(client))
		{
			g_bJoinSqlQueued[client] = false;
		}
		LogFormatted(Debug_SQL, "sql", "Join insert failed. userid=%d client=%d error=%s", userId, client, error);
		delete results;
		return;
	}

	delete results;
	LogFormatted(Debug_SQL, "sql", "Join insert completed. userid=%d client=%d", userId, client);
}

void QueueConnectedJoinInserts()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!ShouldLogConnect(client) || !g_bJoinHandled[client])
		{
			continue;
		}

		QueueJoinInsert(client);
	}
}

bool ResolveLookupIdentity(int requester, const char[] rawInput, bool &useAccountId, int &accountId, char[] steam64, int steam64Len, char[] label, int labelLen)
{
	char input[128];
	strcopy(input, sizeof(input), rawInput);
	TrimString(input);
	StripQuotes(input);

	useAccountId = false;
	accountId = 0;
	steam64[0] = '\0';
	label[0] = '\0';

	if (input[0] == '\0')
	{
		return false;
	}

	if (IsNumericString(input))
	{
		if (strlen(input) >= 16)
		{
			strcopy(steam64, steam64Len, input);
			strcopy(label, labelLen, input);
			return true;
		}

		accountId = StringToInt(input);
		useAccountId = accountId > 0;
		if (useAccountId)
		{
			strcopy(label, labelLen, input);
		}
		return useAccountId;
	}

	if (requester <= 0)
	{
		return false;
	}

	int target = FindTarget(requester, input, true, false);
	if (target <= 0)
	{
		return false;
	}

	accountId = GetSteamAccountID(target);
	GetClientAuthId(target, AuthId_SteamID64, steam64, steam64Len, true);
	FormatEx(label, labelLen, "%N", target);

	if (accountId > 0)
	{
		useAccountId = true;
		return true;
	}

	return steam64[0] != '\0';
}

void RefreshMapState()
{
	GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
	g_bMapBannerPending = true;
}

void GetTimestamp(char[] buffer, int maxlen)
{
	FormatTime(buffer, maxlen, "%Y-%m-%d %H:%M:%S");
}

void GetDateStamp(char[] buffer, int maxlen)
{
	static char format[32];

	if (g_cvFileNameFormat != null)
	{
		g_cvFileNameFormat.GetString(format, sizeof(format));
	}
	else
	{
		strcopy(format, sizeof(format), "%Y%m%d");
	}

	FormatTime(buffer, maxlen, format);
}

void EnsureLogTargets()
{
	static char stamp[32];
	static char logsDir[PLATFORM_MAX_PATH];

	BuildPath(Path_SM, logsDir, sizeof(logsDir), "logs/chats");
	if (!DirExists(logsDir))
	{
		CreateDirectory(logsDir, 511);
	}

	GetDateStamp(stamp, sizeof(stamp));
	if (!StrEqual(stamp, g_sCurrentStamp))
	{
		strcopy(g_sCurrentStamp, sizeof(g_sCurrentStamp), stamp);
		BuildPath(Path_SM, g_sChatFile, sizeof(g_sChatFile), "logs/chats/chat_%s.log", stamp);
		BuildPath(Path_SM, g_sJoinFile, sizeof(g_sJoinFile), "logs/chats/join.log");
		g_bMapBannerPending = true;
		LogFormatted(Debug_General, "debug", "Rotated log targets. chat=%s join=%s", g_sChatFile, g_sJoinFile);
	}
}

void WriteMapBannerIfNeeded()
{
	if (!g_bMapBannerPending)
	{
		return;
	}

	EnsureLogTargets();

	char timestamp[64];
	char line[1024];
	GetTimestamp(timestamp, sizeof(timestamp));
	WriteRawLine(g_sChatFile, "--=================================================================--");
	FormatEx(line, sizeof(line), "[%s] --- Map: %s ---", timestamp, g_sCurrentMap);
	WriteRawLine(g_sChatFile, line);
	WriteRawLine(g_sChatFile, "--=================================================================--");
	g_bMapBannerPending = false;
}

bool WriteRawLine(const char[] filePath, const char[] line)
{
	Handle file = OpenFile(filePath, "a");
	if (file == null)
	{
		LogFormatted(Debug_General, "debug", "OpenFile failed. path=%s", filePath);
		return false;
	}

	WriteFileLine(file, line);
	delete file;
	return true;
}

void WriteMessage(const char[] line)
{
	EnsureLogTargets();
	WriteMapBannerIfNeeded();
	WriteRawLine(g_sChatFile, line);
}

void WriteJoinMessage(const char[] line)
{
	EnsureLogTargets();
	WriteRawLine(g_sJoinFile, line);
}

bool ShouldLogConnect(int client)
{
	if (g_cvEnabled == null || !g_cvEnabled.BoolValue || g_cvLogConnect == null || !g_cvLogConnect.BoolValue)
	{
		return false;
	}

	if (!IsValidClient(client) || !IsClientInGame(client))
	{
		return false;
	}

	if (IsFakeClient(client) && (g_cvLogFakeClients == null || !g_cvLogFakeClients.BoolValue))
	{
		return false;
	}

	return true;
}

bool ShouldLogChat(int client, L4D2CommChannel channel)
{
	if (channel == L4D2CommChannel_Public)
	{
		if (client == 0)
		{
			return g_cvLogConsole != null && g_cvLogConsole.BoolValue;
		}

		return g_cvLogPublic != null && g_cvLogPublic.BoolValue;
	}

	return g_cvLogTeam != null && g_cvLogTeam.BoolValue;
}

bool ShouldLogBlockedChat(int client, L4D2CommChannel channel)
{
	if (g_cvLogBlocked == null || !g_cvLogBlocked.BoolValue)
	{
		return false;
	}

	if (channel == L4D2CommChannel_Public)
	{
		if (client == 0)
		{
			return g_cvLogConsole != null && g_cvLogConsole.BoolValue;
		}

		return true;
	}

	return true;
}

void GetIdentityFields(int client, char[] steam2, int steam2Len, char[] steam64, int steam64Len, char[] ip, int ipLen, char[] country, int countryLen)
{
	steam2[0] = '\0';
	steam64[0] = '\0';
	ip[0] = '\0';
	country[0] = '\0';

	if (!IsValidClient(client) || !IsClientConnected(client))
	{
		return;
	}

	GetClientAuthId(client, AuthId_Steam2, steam2, steam2Len, true);
	GetClientAuthId(client, AuthId_SteamID64, steam64, steam64Len, true);

	if (!GetClientIP(client, ip, ipLen, true))
	{
		strcopy(ip, ipLen, "unknown");
	}

	if (!GeoipCountry(ip, country, countryLen))
	{
		strcopy(country, countryLen, "Unknown");
	}
}

void FormatRenderedChatLine(int client, L4D2CommChannel channel, const char[] prefix, const char[] name, const char[] text, char[] buffer, int maxlen)
{
	char timestamp[64];
	char teamLabel[16];
	char channelLabel[12];

	GetTimestamp(timestamp, sizeof(timestamp));

	if (channel == L4D2CommChannel_Team)
	{
		strcopy(channelLabel, sizeof(channelLabel), "TEAM");
	}
	else
	{
		strcopy(channelLabel, sizeof(channelLabel), "PUBLIC");
	}

	if (client == 0)
	{
		FormatEx(buffer, maxlen, "[%s] [CONSOLE][%s] %s%s : %s", timestamp, channelLabel, prefix, name, text);
		return;
	}

	L4D2CS_GetTeamLabel(L4D_GetClientTeam(client), teamLabel, sizeof(teamLabel));
	FormatEx(buffer, maxlen, "[%s] [%s][%s] %s%s : %s", timestamp, teamLabel, channelLabel, prefix, name, text);
}

void FormatBlockedChatLine(int client, L4D2CommChannel channel, const char[] text, char[] buffer, int maxlen)
{
	char timestamp[64];
	char teamLabel[16];
	char channelLabel[20];

	GetTimestamp(timestamp, sizeof(timestamp));

	if (channel == L4D2CommChannel_Team)
	{
		strcopy(channelLabel, sizeof(channelLabel), "TEAM-BLOCKED");
	}
	else
	{
		strcopy(channelLabel, sizeof(channelLabel), "PUBLIC-BLOCKED");
	}

	if (client == 0)
	{
		FormatEx(buffer, maxlen, "[%s] [CONSOLE][%s] : %s", timestamp, channelLabel, text);
		return;
	}

	L4D2CS_GetTeamLabel(L4D_GetClientTeam(client), teamLabel, sizeof(teamLabel));
	FormatEx(buffer, maxlen, "[%s] [%s][%s] %N : %s", timestamp, teamLabel, channelLabel, client, text);
}

void FormatLifecycleLine(int client, const char[] actionName, const char[] detailText, char[] buffer, int maxlen)
{
	char timestamp[64];
	char steam2[32];
	char steam64[32];
	char ip[32];
	char country[64];

	GetTimestamp(timestamp, sizeof(timestamp));
	GetIdentityFields(client, steam2, sizeof(steam2), steam64, sizeof(steam64), ip, sizeof(ip), country, sizeof(country));

	if (g_cvDetail != null && g_cvDetail.BoolValue)
	{
		if (detailText[0] != '\0')
		{
			FormatEx(
				buffer,
				maxlen,
				"[%s] [%s] %N <%s><%s><%s><%s> : %s",
				timestamp,
				actionName,
				client,
				steam2,
				steam64,
				ip,
				country,
				detailText
			);
			return;
		}

		FormatEx(
			buffer,
			maxlen,
			"[%s] [%s] %N <%s><%s><%s><%s>",
			timestamp,
			actionName,
			client,
			steam2,
			steam64,
			ip,
			country
		);
		return;
	}

	if (detailText[0] != '\0')
	{
		FormatEx(buffer, maxlen, "[%s] [%s] %N : %s", timestamp, actionName, client, detailText);
		return;
	}

	FormatEx(buffer, maxlen, "[%s] [%s] %N", timestamp, actionName, client);
}

void FormatJoinAuditLine(int client, char[] buffer, int maxlen)
{
	char timestamp[64];
	char steam2[32];
	char steam64[32];
	char ip[32];
	char country[64];

	GetTimestamp(timestamp, sizeof(timestamp));
	GetIdentityFields(client, steam2, sizeof(steam2), steam64, sizeof(steam64), ip, sizeof(ip), country, sizeof(country));
	FormatEx(buffer, maxlen, "[%s] %N | %s | %s | %s | %s", timestamp, client, steam2, steam64, ip, country);
}

void InitCommands()
{
	RegAdminCmd("sm_l4d2_chatlog_status", Command_Status, ADMFLAG_GENERIC, "Show L4D2 ChatLog status.");
	RegAdminCmd("sm_l4d2_chatlog_sql_reconnect", Command_SQLReconnect, ADMFLAG_ROOT, "Reconnect the L4D2 ChatLog SQL backend.");
	RegAdminCmd("sm_l4d2_chatlog_join_summary", Command_JoinSummary, ADMFLAG_GENERIC, "Show aggregate join audit stats for an identity.");
	RegAdminCmd("sm_l4d2_chatlog_join_history", Command_JoinHistory, ADMFLAG_GENERIC, "Show join audit history for an accountid, steamid64 or connected player.");
	RegAdminCmd("sm_l4d2_chatlog_join_related", Command_JoinRelated, ADMFLAG_GENERIC, "Show related accounts that shared IPs with an identity.");
	RegAdminCmd("sm_l4d2_chatlog_join_ip", Command_JoinIp, ADMFLAG_GENERIC, "Show accounts observed on a specific IP.");
}

public Action Command_Status(int client, int args)
{
	EnsureLogTargets();
	ReplyCommand(
		client,
		"[L4D2 ChatLog] core=%d debug_mask=%d enabled=%d public=%d team=%d connect=%d disconnect=%d name=%d teamchange=%d detail=%d join_audit=%d sql_enabled=%d sql_ready=%d sql_connecting=%d sql_config=%s chat=%s",
		g_bCoreAvailable,
		g_cvDebugMask != null ? g_cvDebugMask.IntValue : 0,
		g_cvEnabled != null ? g_cvEnabled.BoolValue : false,
		g_cvLogPublic != null ? g_cvLogPublic.BoolValue : false,
		g_cvLogTeam != null ? g_cvLogTeam.BoolValue : false,
		g_cvLogConnect != null ? g_cvLogConnect.BoolValue : false,
		g_cvLogDisconnect != null ? g_cvLogDisconnect.BoolValue : false,
		g_cvLogNameChange != null ? g_cvLogNameChange.BoolValue : false,
		g_cvLogPlayerTeam != null ? g_cvLogPlayerTeam.BoolValue : false,
		g_cvDetail != null ? g_cvDetail.BoolValue : false,
		g_cvJoinAudit != null ? g_cvJoinAudit.BoolValue : false,
		g_cvSqlEnabled != null ? g_cvSqlEnabled.BoolValue : false,
		g_bDbReady,
		g_bDbConnecting,
		g_sDbConfig,
		g_sChatFile
	);
	return Plugin_Handled;
}

public Action Command_SQLReconnect(int client, int args)
{
	RefreshSqlConnection(true);
	ReplyCommand(client, "[L4D2 ChatLog] SQL reconnect requested.");
	return Plugin_Handled;
}

public Action Command_JoinSummary(int client, int args)
{
	if (!CanUseDatabase())
	{
		ReplyCommand(client, "[L4D2 ChatLog] SQL backend is not ready.");
		return Plugin_Handled;
	}

	if (args < 1)
	{
		ReplyCommand(client, "[L4D2 ChatLog] Usage: sm_l4d2_chatlog_join_summary <target|accountid|steamid64> [days] [server_id]");
		return Plugin_Handled;
	}

	bool useAccountId;
	int accountId;
	int days = g_cvSqlDefaultRelatedDays != null ? g_cvSqlDefaultRelatedDays.IntValue : 30;
	int userId = L4D2CS_GetCommandUserId(client);
	char input[128];
	char steam64[32];
	char label[128];
	char serverFilter[64];
	char query[1024];
	DataPack pack = new DataPack();

	GetCmdArg(1, input, sizeof(input));
	if (!ResolveLookupIdentity(client, input, useAccountId, accountId, steam64, sizeof(steam64), label, sizeof(label)))
	{
		ReplyCommand(client, "[L4D2 ChatLog] Invalid identity.");
		delete pack;
		return Plugin_Handled;
	}

	if (args >= 2)
	{
		GetCmdArg(2, input, sizeof(input));
		int parsedDays = StringToInt(input);
		if (parsedDays > 0)
		{
			days = parsedDays;
		}
	}

	GetOptionalServerFilter(args, 3, serverFilter, sizeof(serverFilter));

	pack.WriteCell(userId);
	pack.WriteString(label);
	pack.WriteCell(days);
	pack.WriteString(serverFilter);

	int iLen = 0;
	iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "SELECT COUNT(*), COUNT(DISTINCT IF(`ip_address` <> '', `ip_address`, NULL)), COUNT(DISTINCT IF(`server_id` <> '', `server_id`, NULL)), ");
	iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "DATE_FORMAT(MIN(`joined_at`), '%%Y-%%m-%%d %%H:%%i:%%s'), DATE_FORMAT(MAX(`joined_at`), '%%Y-%%m-%%d %%H:%%i:%%s'), MAX(`player_name`) ");
	iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "FROM `%s` ", L4D2_CHATLOG_SQL_TABLE);

	if (useAccountId)
	{
		iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "WHERE `accountid` = %d ", accountId);
	}
	else
	{
		iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "WHERE `steamid64` = '%s' ", steam64);
	}

	iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "AND `joined_at` >= DATE_SUB(NOW(), INTERVAL %d DAY) ", days);
	if (serverFilter[0] != '\0')
	{
		iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "AND `server_id` = '%s' ", serverFilter);
	}
	iLen += g_db.Format(query[iLen], sizeof(query) - iLen, ";");

	LogFormatted(Debug_SQL, "sql", "Queueing summary query. label=%s days=%d server=%s", label, days, serverFilter[0] != '\0' ? serverFilter : "all");
	g_db.Query(OnJoinSummaryQuery, query, pack);
	return Plugin_Handled;
}

public Action Command_JoinHistory(int client, int args)
{
	if (!CanUseDatabase())
	{
		ReplyCommand(client, "[L4D2 ChatLog] SQL backend is not ready.");
		return Plugin_Handled;
	}

	if (args < 1)
	{
		ReplyCommand(client, "[L4D2 ChatLog] Usage: sm_l4d2_chatlog_join_history <target|accountid|steamid64> [limit] [server_id]");
		return Plugin_Handled;
	}

	bool useAccountId;
	int accountId;
	int limit = g_cvSqlDefaultHistoryLimit != null ? g_cvSqlDefaultHistoryLimit.IntValue : 25;
	int userId = L4D2CS_GetCommandUserId(client);
	char input[128];
	char steam64[32];
	char label[128];
	char serverFilter[64];
	char query[1024];
	DataPack pack = new DataPack();

	GetCmdArg(1, input, sizeof(input));
	if (args >= 2)
	{
		GetCmdArg(2, input, sizeof(input));
		int parsedLimit = StringToInt(input);
		if (parsedLimit > 0)
		{
			limit = parsedLimit;
		}
	}
	GetOptionalServerFilter(args, 3, serverFilter, sizeof(serverFilter));

	GetCmdArg(1, input, sizeof(input));
	if (!ResolveLookupIdentity(client, input, useAccountId, accountId, steam64, sizeof(steam64), label, sizeof(label)))
	{
		ReplyCommand(client, "[L4D2 ChatLog] Invalid identity.");
		delete pack;
		return Plugin_Handled;
	}

	pack.WriteCell(userId);
	pack.WriteString(label);
	pack.WriteCell(limit);
	pack.WriteString(serverFilter);

	int iLen = 0;
	iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "SELECT DATE_FORMAT(`joined_at`, '%%Y-%%m-%%d %%H:%%i:%%s'), `server_id`, `player_name`, `steamid64`, `accountid`, `ip_address`, `country` ");
	iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "FROM `%s` ", L4D2_CHATLOG_SQL_TABLE);

	if (useAccountId)
	{
		iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "WHERE `accountid` = %d ", accountId);
	}
	else
	{
		iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "WHERE `steamid64` = '%s' ", steam64);
	}

	if (serverFilter[0] != '\0')
	{
		iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "AND `server_id` = '%s' ", serverFilter);
	}

	iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "ORDER BY `joined_at` DESC LIMIT %d;", limit);

	LogFormatted(Debug_SQL, "sql", "Queueing history query. label=%s limit=%d server=%s", label, limit, serverFilter[0] != '\0' ? serverFilter : "all");
	g_db.Query(OnJoinHistoryQuery, query, pack);
	return Plugin_Handled;
}

public Action Command_JoinRelated(int client, int args)
{
	if (!CanUseDatabase())
	{
		ReplyCommand(client, "[L4D2 ChatLog] SQL backend is not ready.");
		return Plugin_Handled;
	}

	if (args < 1)
	{
		ReplyCommand(client, "[L4D2 ChatLog] Usage: sm_l4d2_chatlog_join_related <target|accountid|steamid64> [days] [min_shared] [limit] [server_id]");
		return Plugin_Handled;
	}

	bool useAccountId;
	int accountId;
	int days = g_cvSqlDefaultRelatedDays != null ? g_cvSqlDefaultRelatedDays.IntValue : 30;
	int minShared = g_cvSqlDefaultRelatedMinShared != null ? g_cvSqlDefaultRelatedMinShared.IntValue : 2;
	int limit = 25;
	int userId = L4D2CS_GetCommandUserId(client);
	char input[128];
	char steam64[32];
	char label[128];
	char serverFilter[64];
	char query[2048];
	DataPack pack = new DataPack();

	GetCmdArg(1, input, sizeof(input));
	if (!ResolveLookupIdentity(client, input, useAccountId, accountId, steam64, sizeof(steam64), label, sizeof(label)))
	{
		ReplyCommand(client, "[L4D2 ChatLog] Invalid identity.");
		delete pack;
		return Plugin_Handled;
	}

	if (args >= 2)
	{
		GetCmdArg(2, input, sizeof(input));
		int parsedDays = StringToInt(input);
		if (parsedDays > 0)
		{
			days = parsedDays;
		}
	}

	if (args >= 3)
	{
		GetCmdArg(3, input, sizeof(input));
		int parsedMinShared = StringToInt(input);
		if (parsedMinShared > 0)
		{
			minShared = parsedMinShared;
		}
	}

	if (args >= 4)
	{
		GetCmdArg(4, input, sizeof(input));
		int parsedLimit = StringToInt(input);
		if (parsedLimit > 0)
		{
			limit = parsedLimit;
		}
	}
	GetOptionalServerFilter(args, 5, serverFilter, sizeof(serverFilter));

	pack.WriteCell(userId);
	pack.WriteString(label);
	pack.WriteCell(days);
	pack.WriteCell(minShared);
	pack.WriteCell(limit);
	pack.WriteString(serverFilter);

	int iLen = 0;
	iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "SELECT `related`.`ip_address`, `related`.`accountid`, `related`.`steamid64`, MAX(`related`.`player_name`), COUNT(*), ");
	iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "DATE_FORMAT(MIN(`related`.`joined_at`), '%%Y-%%m-%%d %%H:%%i:%%s'), DATE_FORMAT(MAX(`related`.`joined_at`), '%%Y-%%m-%%d %%H:%%i:%%s') ");
	iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "FROM `%s` `related` ", L4D2_CHATLOG_SQL_TABLE);
	iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "JOIN (SELECT DISTINCT `ip_address` FROM `%s` ", L4D2_CHATLOG_SQL_TABLE);
	iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "WHERE `joined_at` >= DATE_SUB(NOW(), INTERVAL %d DAY) AND `ip_address` <> '' ", days);

	if (useAccountId)
	{
		iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "AND `accountid` = %d ", accountId);
	}
	else
	{
		iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "AND `steamid64` = '%s' ", steam64);
	}

	if (serverFilter[0] != '\0')
	{
		iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "AND `server_id` = '%s' ", serverFilter);
	}

	iLen += g_db.Format(query[iLen], sizeof(query) - iLen, ") `target_ips` ");
	iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "ON `target_ips`.`ip_address` = `related`.`ip_address` ");
	iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "WHERE `related`.`joined_at` >= DATE_SUB(NOW(), INTERVAL %d DAY) ", days);

	if (useAccountId)
	{
		iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "AND `related`.`accountid` <> %d ", accountId);
	}
	else
	{
		iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "AND `related`.`steamid64` <> '%s' ", steam64);
	}

	if (serverFilter[0] != '\0')
	{
		iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "AND `related`.`server_id` = '%s' ", serverFilter);
	}

	iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "GROUP BY `related`.`ip_address`, `related`.`accountid`, `related`.`steamid64` ");
	iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "HAVING COUNT(*) >= %d ", minShared);
	iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "ORDER BY COUNT(*) DESC, MAX(`related`.`joined_at`) DESC LIMIT %d;", limit);

	LogFormatted(Debug_SQL, "sql", "Queueing related query. label=%s days=%d min=%d limit=%d server=%s", label, days, minShared, limit, serverFilter[0] != '\0' ? serverFilter : "all");
	g_db.Query(OnJoinRelatedQuery, query, pack);
	return Plugin_Handled;
}

public Action Command_JoinIp(int client, int args)
{
	if (!CanUseDatabase())
	{
		ReplyCommand(client, "[L4D2 ChatLog] SQL backend is not ready.");
		return Plugin_Handled;
	}

	if (args < 1)
	{
		ReplyCommand(client, "[L4D2 ChatLog] Usage: sm_l4d2_chatlog_join_ip <ip> [days] [limit] [server_id]");
		return Plugin_Handled;
	}

	int days = g_cvSqlDefaultRelatedDays != null ? g_cvSqlDefaultRelatedDays.IntValue : 30;
	int limit = g_cvSqlDefaultHistoryLimit != null ? g_cvSqlDefaultHistoryLimit.IntValue : 25;
	int userId = L4D2CS_GetCommandUserId(client);
	char ipAddress[64];
	char serverFilter[64];
	char query[1024];
	DataPack pack = new DataPack();

	GetCmdArg(1, ipAddress, sizeof(ipAddress));
	TrimString(ipAddress);
	StripQuotes(ipAddress);

	if (!IsLikelyIpAddress(ipAddress))
	{
		ReplyCommand(client, "[L4D2 ChatLog] Invalid IP.");
		delete pack;
		return Plugin_Handled;
	}

	if (args >= 2)
	{
		char input[32];
		GetCmdArg(2, input, sizeof(input));
		int parsedDays = StringToInt(input);
		if (parsedDays > 0)
		{
			days = parsedDays;
		}
	}

	if (args >= 3)
	{
		char input[32];
		GetCmdArg(3, input, sizeof(input));
		int parsedLimit = StringToInt(input);
		if (parsedLimit > 0)
		{
			limit = parsedLimit;
		}
	}
	GetOptionalServerFilter(args, 4, serverFilter, sizeof(serverFilter));

	pack.WriteCell(userId);
	pack.WriteString(ipAddress);
	pack.WriteCell(days);
	pack.WriteCell(limit);
	pack.WriteString(serverFilter);

	int iLen = 0;
	iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "SELECT `accountid`, `steamid64`, MAX(`player_name`), COUNT(*), DATE_FORMAT(MIN(`joined_at`), '%%Y-%%m-%%d %%H:%%i:%%s'), DATE_FORMAT(MAX(`joined_at`), '%%Y-%%m-%%d %%H:%%i:%%s'), MAX(`country`) ");
	iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "FROM `%s` ", L4D2_CHATLOG_SQL_TABLE);
	iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "WHERE `ip_address` = '%s' ", ipAddress);
	iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "AND `joined_at` >= DATE_SUB(NOW(), INTERVAL %d DAY) ", days);

	if (serverFilter[0] != '\0')
	{
		iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "AND `server_id` = '%s' ", serverFilter);
	}

	iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "GROUP BY `accountid`, `steamid64` ");
	iLen += g_db.Format(query[iLen], sizeof(query) - iLen, "ORDER BY COUNT(*) DESC, MAX(`joined_at`) DESC LIMIT %d;", limit);

	LogFormatted(Debug_SQL, "sql", "Queueing IP query. ip=%s days=%d limit=%d server=%s", ipAddress, days, limit, serverFilter[0] != '\0' ? serverFilter : "all");
	g_db.Query(OnJoinIpQuery, query, pack);
	return Plugin_Handled;
}

public void OnJoinHistoryQuery(Database db, DBResultSet results, const char[] error, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	int userId = pack.ReadCell();
	char label[128];
	pack.ReadString(label, sizeof(label));
	int limit = pack.ReadCell();
	char serverFilter[64];
	pack.ReadString(serverFilter, sizeof(serverFilter));
	delete pack;

	if (db == null || db != g_db || results == null)
	{
		ReplyAsync(userId, "[L4D2 ChatLog] Join history query failed: %s", error);
		return;
	}

	ReplyAsync(userId, "[L4D2 ChatLog] Join history for %s (limit=%d server=%s):", label, limit, serverFilter[0] != '\0' ? serverFilter : "all");

	int rows = 0;
	while (results.FetchRow())
	{
		char joinedAt[32];
		char serverId[64];
		char playerName[128];
		char steam64[32];
		char ipAddress[45];
		char country[64];
		int accountId = results.FetchInt(4);

		results.FetchString(0, joinedAt, sizeof(joinedAt));
		results.FetchString(1, serverId, sizeof(serverId));
		results.FetchString(2, playerName, sizeof(playerName));
		results.FetchString(3, steam64, sizeof(steam64));
		results.FetchString(5, ipAddress, sizeof(ipAddress));
		results.FetchString(6, country, sizeof(country));

		PrintQueryLine(
			userId,
			"[%s] server=%s name=%s accountid=%d steamid64=%s ip=%s country=%s",
			joinedAt,
			serverId,
			playerName,
			accountId,
			steam64,
			ipAddress,
			country
		);
		rows++;
	}

	if (rows == 0)
	{
		ReplyAsync(userId, "[L4D2 ChatLog] No join rows found.");
	}
}

public void OnJoinSummaryQuery(Database db, DBResultSet results, const char[] error, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	int userId = pack.ReadCell();
	char label[128];
	pack.ReadString(label, sizeof(label));
	int days = pack.ReadCell();
	char serverFilter[64];
	pack.ReadString(serverFilter, sizeof(serverFilter));
	delete pack;

	if (db == null || db != g_db || results == null)
	{
		ReplyAsync(userId, "[L4D2 ChatLog] Summary query failed: %s", error);
		return;
	}

	if (!results.FetchRow())
	{
		ReplyAsync(userId, "[L4D2 ChatLog] No summary rows found.");
		return;
	}

	int joinsCount = results.FetchInt(0);
	int uniqueIps = results.FetchInt(1);
	int uniqueServers = results.FetchInt(2);
	char firstSeen[32];
	char lastSeen[32];
	char lastName[128];

	results.FetchString(3, firstSeen, sizeof(firstSeen));
	results.FetchString(4, lastSeen, sizeof(lastSeen));
	results.FetchString(5, lastName, sizeof(lastName));

	ReplyAsync(
		userId,
		"[L4D2 ChatLog] Summary for %s (days=%d server=%s): joins=%d unique_ips=%d unique_servers=%d first=%s last=%s last_name=%s",
		label,
		days,
		serverFilter[0] != '\0' ? serverFilter : "all",
		joinsCount,
		uniqueIps,
		uniqueServers,
		firstSeen[0] != '\0' ? firstSeen : "n/a",
		lastSeen[0] != '\0' ? lastSeen : "n/a",
		lastName[0] != '\0' ? lastName : "n/a"
	);
}

public void OnJoinRelatedQuery(Database db, DBResultSet results, const char[] error, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	int userId = pack.ReadCell();
	char label[128];
	pack.ReadString(label, sizeof(label));
	int days = pack.ReadCell();
	int minShared = pack.ReadCell();
	int limit = pack.ReadCell();
	char serverFilter[64];
	pack.ReadString(serverFilter, sizeof(serverFilter));
	delete pack;

	if (db == null || db != g_db || results == null)
	{
		ReplyAsync(userId, "[L4D2 ChatLog] Related query failed: %s", error);
		return;
	}

	ReplyAsync(userId, "[L4D2 ChatLog] Related accounts for %s (days=%d min_shared=%d limit=%d server=%s):", label, days, minShared, limit, serverFilter[0] != '\0' ? serverFilter : "all");

	int rows = 0;
	while (results.FetchRow())
	{
		char ipAddress[45];
		char steam64[32];
		char playerName[128];
		char firstSeen[32];
		char lastSeen[32];
		int accountId = results.FetchInt(1);
		int sharedJoins = results.FetchInt(4);

		results.FetchString(0, ipAddress, sizeof(ipAddress));
		results.FetchString(2, steam64, sizeof(steam64));
		results.FetchString(3, playerName, sizeof(playerName));
		results.FetchString(5, firstSeen, sizeof(firstSeen));
		results.FetchString(6, lastSeen, sizeof(lastSeen));

		PrintQueryLine(
			userId,
			"ip=%s accountid=%d steamid64=%s name=%s shared=%d first=%s last=%s",
			ipAddress,
			accountId,
			steam64,
			playerName,
			sharedJoins,
			firstSeen,
			lastSeen
		);
		rows++;
	}

	if (rows == 0)
	{
		ReplyAsync(userId, "[L4D2 ChatLog] No related accounts found.");
	}
}

public void OnJoinIpQuery(Database db, DBResultSet results, const char[] error, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	int userId = pack.ReadCell();
	char ipAddress[64];
	pack.ReadString(ipAddress, sizeof(ipAddress));
	int days = pack.ReadCell();
	int limit = pack.ReadCell();
	char serverFilter[64];
	pack.ReadString(serverFilter, sizeof(serverFilter));
	delete pack;

	if (db == null || db != g_db || results == null)
	{
		ReplyAsync(userId, "[L4D2 ChatLog] IP query failed: %s", error);
		return;
	}

	ReplyAsync(userId, "[L4D2 ChatLog] Accounts seen on IP %s (days=%d limit=%d server=%s):", ipAddress, days, limit, serverFilter[0] != '\0' ? serverFilter : "all");

	int rows = 0;
	while (results.FetchRow())
	{
		int accountId = results.FetchInt(0);
		char steam64[32];
		char playerName[128];
		int joinsCount = results.FetchInt(3);
		char firstSeen[32];
		char lastSeen[32];
		char country[64];

		results.FetchString(1, steam64, sizeof(steam64));
		results.FetchString(2, playerName, sizeof(playerName));
		results.FetchString(4, firstSeen, sizeof(firstSeen));
		results.FetchString(5, lastSeen, sizeof(lastSeen));
		results.FetchString(6, country, sizeof(country));

		PrintQueryLine(
			userId,
			"accountid=%d steamid64=%s name=%s joins=%d first=%s last=%s country=%s",
			accountId,
			steam64,
			playerName,
			joinsCount,
			firstSeen,
			lastSeen,
			country
		);
		rows++;
	}

	if (rows == 0)
	{
		ReplyAsync(userId, "[L4D2 ChatLog] No accounts found for that IP.");
	}
}
