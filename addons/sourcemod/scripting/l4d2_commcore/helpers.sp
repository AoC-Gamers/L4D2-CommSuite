#if defined _l4d2_commcore_helpers_included
	#endinput
#endif
#define _l4d2_commcore_helpers_included

bool L4D2Comm_DebugEnabled(int bit)
{
	return L4D2CS_DebugMaskEnabled(g_cvL4D2Comm_LogMode, g_cvL4D2Comm_DebugMask, bit);
}

bool L4D2Comm_IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientConnected(client);
}

bool L4D2Comm_IsInGameHuman(int client)
{
	return L4D2Comm_IsValidClient(client) && IsClientInGame(client) && !IsFakeClient(client);
}

L4D2CommChannel L4D2Comm_GetChannelForCommand(const char[] command)
{
	if (StrEqual(command, "say_team", false))
	{
		return L4D2CommChannel_Team;
	}

	return L4D2CommChannel_Public;
}

Action L4D2Comm_CallChatPreForward(int client, L4D2CommChannel channel, const char[] text)
{
	if (g_hL4D2Comm_FwdOnChatMessage == INVALID_HANDLE)
	{
		return Plugin_Continue;
	}

	Action result = Plugin_Continue;
	Call_StartForward(g_hL4D2Comm_FwdOnChatMessage);
	Call_PushCell(client);
	Call_PushCell(channel);
	Call_PushString(text);
	Call_Finish(result);
	return result;
}

Action L4D2Comm_CallChatRenderForward(int client, L4D2CommChannel channel, char[] prefix, int prefixLen, char[] name, int nameLen, char[] text, int textLen)
{
	if (g_hL4D2Comm_FwdOnChatRender == INVALID_HANDLE)
	{
		return Plugin_Continue;
	}

	Action result = Plugin_Continue;
	Call_StartForward(g_hL4D2Comm_FwdOnChatRender);
	Call_PushCell(client);
	Call_PushCell(channel);
	Call_PushStringEx(prefix, prefixLen, SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushStringEx(name, nameLen, SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushStringEx(text, textLen, SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_Finish(result);
	return result;
}

void L4D2Comm_CallChatPostForward(int client, L4D2CommChannel channel, const char[] text)
{
	if (g_hL4D2Comm_FwdOnChatMessagePost == INVALID_HANDLE)
	{
		return;
	}

	Call_StartForward(g_hL4D2Comm_FwdOnChatMessagePost);
	Call_PushCell(client);
	Call_PushCell(channel);
	Call_PushString(text);
	Call_Finish();
}

void L4D2Comm_CallChatRenderedPostForward(int client, L4D2CommChannel channel, const char[] prefix, const char[] name, const char[] text)
{
	if (g_hL4D2Comm_FwdOnChatMessageRenderedPost == INVALID_HANDLE)
	{
		return;
	}

	Call_StartForward(g_hL4D2Comm_FwdOnChatMessageRenderedPost);
	Call_PushCell(client);
	Call_PushCell(channel);
	Call_PushString(prefix);
	Call_PushString(name);
	Call_PushString(text);
	Call_Finish();
}

void L4D2Comm_CallChatBlockedForward(int client, L4D2CommChannel channel, const char[] text)
{
	if (g_hL4D2Comm_FwdOnChatMessageBlocked == INVALID_HANDLE)
	{
		return;
	}

	Call_StartForward(g_hL4D2Comm_FwdOnChatMessageBlocked);
	Call_PushCell(client);
	Call_PushCell(channel);
	Call_PushString(text);
	Call_Finish();
}

void L4D2Comm_BuildDefaultChatRender(int client, char[] prefix, char[] name, int nameLen)
{
	prefix[0] = '\0';
	FormatEx(name, nameLen, "%N", client);
}

void L4D2Comm_PrintRenderedChatToServer(int client, L4D2CommChannel channel, const char[] prefix, const char[] name, const char[] text)
{
	char line[512];
	if (channel == L4D2CommChannel_Team)
	{
		char teamLabel[16];
		L4D2CS_GetTeamLabel(L4D_GetClientTeam(client), teamLabel, sizeof(teamLabel));
		FormatEx(line, sizeof(line), "(%s) %s%s: %s", teamLabel, prefix, name, text);
	}
	else
	{
		FormatEx(line, sizeof(line), "%s%s: %s", prefix, name, text);
	}

	CRemoveTags(line, sizeof(line));
	PrintToServer("%s", line);
}

bool L4D2Comm_ShouldSendTeamChatToTarget(int author, int target)
{
	if (!L4D2CS_IsConnectedClient(target) || !IsClientInGame(target) || IsFakeClient(target))
	{
		return false;
	}

	if (target == author)
	{
		return true;
	}

	if (IsClientSourceTV(target) || IsClientReplay(target))
	{
		return true;
	}

	L4DTeam authorTeam = L4D_GetClientTeam(author);
	L4DTeam targetTeam = L4D_GetClientTeam(target);

	if (authorTeam == L4DTeam_Spectator)
	{
		return targetTeam == L4DTeam_Spectator;
	}

	if (authorTeam == L4DTeam_Survivor)
	{
		return targetTeam == L4DTeam_Survivor || targetTeam == L4DTeam_Spectator;
	}

	if (authorTeam == L4DTeam_Infected)
	{
		return targetTeam == L4DTeam_Infected || targetTeam == L4DTeam_Spectator;
	}

	return false;
}

void L4D2Comm_EmitRenderedChat(int client, L4D2CommChannel channel, const char[] prefix, const char[] name, const char[] text)
{
	if (!L4D2Comm_IsInGameHuman(client))
	{
		return;
	}

	L4D2Comm_PrintRenderedChatToServer(client, channel, prefix, name, text);

	char message[512];
	if (channel == L4D2CommChannel_Team)
	{
		char teamLabel[16];
		L4D2CS_GetTeamLabel(L4D_GetClientTeam(client), teamLabel, sizeof(teamLabel));
		FormatEx(message, sizeof(message), "{olive}(%s){default} %s{teamcolor}%s{default}: %s", teamLabel, prefix, name, text);
	}
	else
	{
		FormatEx(message, sizeof(message), "%s{teamcolor}%s{default}: %s", prefix, name, text);
	}

	for (int target = 1; target <= MaxClients; target++)
	{
		if (!L4D2CS_IsConnectedClient(target))
		{
			continue;
		}

		if (channel == L4D2CommChannel_Team)
		{
			if (!L4D2Comm_ShouldSendTeamChatToTarget(client, target))
			{
				continue;
			}
		}
		else
		{
			if ((!IsClientInGame(target) || IsFakeClient(target)) && !IsClientSourceTV(target) && !IsClientReplay(target))
			{
				continue;
			}
		}

		CPrintToChatEx(target, client, "%s", message);
	}
}

void L4D2Comm_BuildSuppressedChatSignature(int client, L4D2CommChannel channel, const char[] text, char[] buffer, int maxlen)
{
	Format(buffer, maxlen, "%d|%d|%s", client, channel, text);
}

void L4D2Comm_QueueSuppressedChatPost(int client, L4D2CommChannel channel, const char[] text)
{
	if (g_aL4D2Comm_SuppressedChatPosts == null)
	{
		return;
	}

	char signature[384];
	L4D2Comm_BuildSuppressedChatSignature(client, channel, text, signature, sizeof(signature));
	g_aL4D2Comm_SuppressedChatPosts.PushString(signature);
}

bool L4D2Comm_TakeSuppressedChatPost(int client, L4D2CommChannel channel, const char[] text)
{
	if (g_aL4D2Comm_SuppressedChatPosts == null || g_aL4D2Comm_SuppressedChatPosts.Length == 0)
	{
		return false;
	}

	char signature[384];
	char queuedSignature[384];
	L4D2Comm_BuildSuppressedChatSignature(client, channel, text, signature, sizeof(signature));

	for (int i = 0; i < g_aL4D2Comm_SuppressedChatPosts.Length; i++)
	{
		g_aL4D2Comm_SuppressedChatPosts.GetString(i, queuedSignature, sizeof(queuedSignature));
		if (!StrEqual(queuedSignature, signature))
		{
			continue;
		}

		g_aL4D2Comm_SuppressedChatPosts.Erase(i);
		return true;
	}

	return false;
}

Action L4D2Comm_CallServerCvarForward(const char[] cvarName, const char[] cvarValue)
{
	if (g_hL4D2Comm_FwdOnServerCvarMessage == INVALID_HANDLE)
	{
		return Plugin_Continue;
	}

	Action result = Plugin_Continue;
	Call_StartForward(g_hL4D2Comm_FwdOnServerCvarMessage);
	Call_PushString(cvarName);
	Call_PushString(cvarValue);
	Call_Finish(result);
	return result;
}

Action L4D2Comm_CallPlayerConnectForward(const char[] playerName)
{
	if (g_hL4D2Comm_FwdOnPlayerConnectMessage == INVALID_HANDLE)
	{
		return Plugin_Continue;
	}

	Action result = Plugin_Continue;
	Call_StartForward(g_hL4D2Comm_FwdOnPlayerConnectMessage);
	Call_PushString(playerName);
	Call_Finish(result);
	return result;
}

Action L4D2Comm_CallPlayerDisconnectForward(const char[] playerName, const char[] reason)
{
	if (g_hL4D2Comm_FwdOnPlayerDisconnectMessage == INVALID_HANDLE)
	{
		return Plugin_Continue;
	}

	Action result = Plugin_Continue;
	Call_StartForward(g_hL4D2Comm_FwdOnPlayerDisconnectMessage);
	Call_PushString(playerName);
	Call_PushString(reason);
	Call_Finish(result);
	return result;
}

Action L4D2Comm_CallPlayerNameChangeForward(const char[] oldName, const char[] newName)
{
	if (g_hL4D2Comm_FwdOnPlayerNameChangeMessage == INVALID_HANDLE)
	{
		return Plugin_Continue;
	}

	Action result = Plugin_Continue;
	Call_StartForward(g_hL4D2Comm_FwdOnPlayerNameChangeMessage);
	Call_PushString(oldName);
	Call_PushString(newName);
	Call_Finish(result);
	return result;
}

Action L4D2Comm_CallPlayerTeamForward(const char[] playerName, L4DTeam team, bool disconnect)
{
	if (g_hL4D2Comm_FwdOnPlayerTeamMessage == INVALID_HANDLE)
	{
		return Plugin_Continue;
	}

	Action result = Plugin_Continue;
	Call_StartForward(g_hL4D2Comm_FwdOnPlayerTeamMessage);
	Call_PushString(playerName);
	Call_PushCell(team);
	Call_PushCell(disconnect);
	Call_Finish(result);
	return result;
}

Action L4D2Comm_CallTextMsgForward(const char[] msgKey, const char[] param1, const char[] param2, const char[] param3, const char[] param4, int firstTarget, int playersNum, bool reliable, bool init)
{
	if (g_hL4D2Comm_FwdOnTextMsgMessage == INVALID_HANDLE)
	{
		return Plugin_Continue;
	}

	Action result = Plugin_Continue;
	Call_StartForward(g_hL4D2Comm_FwdOnTextMsgMessage);
	Call_PushString(msgKey);
	Call_PushString(param1);
	Call_PushString(param2);
	Call_PushString(param3);
	Call_PushString(param4);
	Call_PushCell(firstTarget);
	Call_PushCell(playersNum);
	Call_PushCell(reliable);
	Call_PushCell(init);
	Call_Finish(result);
	return result;
}

Action L4D2Comm_CallSayText2Forward(const char[] msgKey, const char[] param1, const char[] param2, const char[] param3, const char[] param4, int firstTarget, int playersNum, bool reliable, bool init)
{
	if (g_hL4D2Comm_FwdOnSayText2Message == INVALID_HANDLE)
	{
		return Plugin_Continue;
	}

	Action result = Plugin_Continue;
	Call_StartForward(g_hL4D2Comm_FwdOnSayText2Message);
	Call_PushString(msgKey);
	Call_PushString(param1);
	Call_PushString(param2);
	Call_PushString(param3);
	Call_PushString(param4);
	Call_PushCell(firstTarget);
	Call_PushCell(playersNum);
	Call_PushCell(reliable);
	Call_PushCell(init);
	Call_Finish(result);
	return result;
}

void L4D2Comm_LogLine(const char[] tag, const char[] message)
{
	L4D2CS_EnsureDebugLogPathReady(g_cvL4D2Comm_LogMode);
	LogToFileEx(g_sLogPath, "%s[%s] %s", L4D2_COMMSUITE_COMMCORE_LOG_PREFIX, tag, message);
}

void L4D2Comm_Debug(const char[] format, any ...)
{
	if (!L4D2Comm_DebugEnabled(L4D2CommDebug_General))
	{
		return;
	}

	static char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 2);
	L4D2Comm_LogLine("debug", buffer);
}

void L4D2Comm_Hook(const char[] format, any ...)
{
	if (!L4D2Comm_DebugEnabled(L4D2CommDebug_Hook))
	{
		return;
	}

	static char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 2);
	L4D2Comm_LogLine("hook", buffer);
}

void L4D2Comm_Noise(const char[] format, any ...)
{
	if (!L4D2Comm_DebugEnabled(L4D2CommDebug_Noise))
	{
		return;
	}

	static char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 2);
	L4D2Comm_LogLine("noise", buffer);
}
