#if defined _l4d2_commcore_noise_included
	#endinput
#endif
#define _l4d2_commcore_noise_included

Action L4D2Comm_HandleNoiseEvent_ServerCvar(Event event)
{
	if (g_cvL4D2Comm_NoiseEnabled == null || !g_cvL4D2Comm_NoiseEnabled.BoolValue)
	{
		return Plugin_Continue;
	}

	static char cvarName[64];
	static char cvarValue[64];
	event.GetString("cvarname", cvarName, sizeof(cvarName));
	event.GetString("cvarvalue", cvarValue, sizeof(cvarValue));
	Action result = L4D2Comm_CallServerCvarForward(cvarName, cvarValue);
	L4D2Comm_Noise("server_cvar intercepted. cvar=%s value=%s result=%d", cvarName, cvarValue, result);
	return result;
}

Action L4D2Comm_HandleNoiseEvent_PlayerConnect(Event event)
{
	if (g_cvL4D2Comm_NoiseEnabled == null || !g_cvL4D2Comm_NoiseEnabled.BoolValue)
	{
		return Plugin_Continue;
	}

	static char playerName[128];
	event.GetString("name", playerName, sizeof(playerName));
	Action result = L4D2Comm_CallPlayerConnectForward(playerName);
	L4D2Comm_Noise("player_connect intercepted. name=%s result=%d", playerName, result);
	return result;
}

Action L4D2Comm_HandleNoiseEvent_PlayerDisconnect(Event event)
{
	if (g_cvL4D2Comm_NoiseEnabled == null || !g_cvL4D2Comm_NoiseEnabled.BoolValue)
	{
		return Plugin_Continue;
	}

	static char playerName[128];
	static char reason[128];
	event.GetString("name", playerName, sizeof(playerName));
	event.GetString("reason", reason, sizeof(reason));
	Action result = L4D2Comm_CallPlayerDisconnectForward(playerName, reason);
	L4D2Comm_Noise("player_disconnect intercepted. name=%s reason=%s result=%d", playerName, reason, result);
	return result;
}

Action L4D2Comm_HandleNoiseEvent_PlayerNameChange(Event event)
{
	if (g_cvL4D2Comm_NoiseEnabled == null || !g_cvL4D2Comm_NoiseEnabled.BoolValue)
	{
		return Plugin_Continue;
	}

	static char oldName[128];
	static char newName[128];
	event.GetString("oldname", oldName, sizeof(oldName));
	event.GetString("newname", newName, sizeof(newName));
	Action result = L4D2Comm_CallPlayerNameChangeForward(oldName, newName);
	L4D2Comm_Noise("player_changename intercepted. old=%s new=%s result=%d", oldName, newName, result);
	return result;
}

Action L4D2Comm_HandleNoiseEvent_PlayerTeam(Event event)
{
	if (g_cvL4D2Comm_NoiseEnabled == null || !g_cvL4D2Comm_NoiseEnabled.BoolValue)
	{
		return Plugin_Continue;
	}

	static char playerName[128];
	event.GetString("name", playerName, sizeof(playerName));
	L4DTeam team = view_as<L4DTeam>(event.GetInt("team"));
	bool disconnect = event.GetBool("disconnect");
	Action result = L4D2Comm_CallPlayerTeamForward(playerName, team, disconnect);
	L4D2Comm_Noise("player_team intercepted. name=%s team=%d disconnect=%d result=%d", playerName, team, disconnect, result);
	return result;
}

Action L4D2Comm_HandleNoiseUserMessage_SayText2(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	if (g_cvL4D2Comm_NoiseEnabled == null || !g_cvL4D2Comm_NoiseEnabled.BoolValue)
	{
		return Plugin_Continue;
	}

	char msgName[32];
	char msgKey[128];
	char msgParam1[128];
	char msgParam2[128];
	char msgParam3[128];
	char msgParam4[128];
	GetUserMessageName(msg_id, msgName, sizeof(msgName));
	if (msg == null)
	{
		L4D2Comm_Noise("%s usermessage stub hit with null payload. players=%d reliable=%d init=%d", msgName, playersNum, reliable, init);
		return Plugin_Continue;
	}

	msgKey[0] = '\0';
	msgParam1[0] = '\0';
	msgParam2[0] = '\0';
	msgParam3[0] = '\0';
	msgParam4[0] = '\0';
	msg.ReadByte();
	msg.ReadByte();
	msg.ReadString(msgKey, sizeof(msgKey), false);
	msg.ReadString(msgParam1, sizeof(msgParam1), false);
	msg.ReadString(msgParam2, sizeof(msgParam2), false);
	msg.ReadString(msgParam3, sizeof(msgParam3), false);
	msg.ReadString(msgParam4, sizeof(msgParam4), false);

	if (msgKey[0] == '\0' && msgParam1[0] == '\0' && msgParam2[0] == '\0' && msgParam3[0] == '\0' && msgParam4[0] == '\0')
	{
		L4D2Comm_Noise("%s usermessage payload decoded as empty. players=%d reliable=%d init=%d", msgName, playersNum, reliable, init);
		return Plugin_Continue;
	}

	int firstClient = playersNum > 0 ? players[0] : 0;
	Action result = L4D2Comm_CallSayText2Forward(msgKey, msgParam1, msgParam2, msgParam3, msgParam4, firstClient, playersNum, reliable, init);
	L4D2Comm_Noise(
		"%s intercepted. key=%s p1=%s p2=%s p3=%s p4=%s players=%d first=%d reliable=%d init=%d result=%d",
		msgName,
		msgKey,
		msgParam1,
		msgParam2,
		msgParam3,
		msgParam4,
		playersNum,
		firstClient,
		reliable,
		init,
		result
	);
	return result;
}

Action L4D2Comm_HandleNoiseUserMessage_TextMsg(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	if (g_cvL4D2Comm_NoiseEnabled == null || !g_cvL4D2Comm_NoiseEnabled.BoolValue)
	{
		return Plugin_Continue;
	}

	char msgName[32];
	char msgKey[128];
	char msgParam1[128];
	char msgParam2[128];
	char msgParam3[128];
	char msgParam4[128];
	GetUserMessageName(msg_id, msgName, sizeof(msgName));
	if (msg == null)
	{
		L4D2Comm_Noise("%s usermessage stub hit with null payload. players=%d reliable=%d init=%d", msgName, playersNum, reliable, init);
		return Plugin_Continue;
	}

	msgKey[0] = '\0';
	msgParam1[0] = '\0';
	msgParam2[0] = '\0';
	msgParam3[0] = '\0';
	msgParam4[0] = '\0';
	int msgDest = msg.ReadByte();
	msg.ReadString(msgKey, sizeof(msgKey), false);
	msg.ReadString(msgParam1, sizeof(msgParam1), false);
	msg.ReadString(msgParam2, sizeof(msgParam2), false);
	msg.ReadString(msgParam3, sizeof(msgParam3), false);
	msg.ReadString(msgParam4, sizeof(msgParam4), false);

	if (msgKey[0] == '\0' && msgParam1[0] == '\0' && msgParam2[0] == '\0' && msgParam3[0] == '\0' && msgParam4[0] == '\0')
	{
		L4D2Comm_Noise("%s usermessage payload decoded as empty. players=%d reliable=%d init=%d", msgName, playersNum, reliable, init);
		return Plugin_Continue;
	}

	int firstClient = playersNum > 0 ? players[0] : 0;
	Action result = L4D2Comm_CallTextMsgForward(msgKey, msgParam1, msgParam2, msgParam3, msgParam4, firstClient, playersNum, reliable, init);
	if (result < Plugin_Handled && L4D2Comm_IsLocalizedChatPromptKey(msgKey))
	{
		L4D2Comm_EmitLocalizedPromptTextMsg(players, playersNum, msgDest, msgKey);
		L4D2Comm_Noise(
			"%s localized prompt replaced. key=%s dest=%d players=%d first=%d reliable=%d init=%d",
			msgName,
			msgKey,
			msgDest,
			playersNum,
			firstClient,
			reliable,
			init
		);
		return Plugin_Handled;
	}

	L4D2Comm_Noise(
		"%s intercepted. key=%s dest=%d p1=%s p2=%s p3=%s p4=%s players=%d first=%d reliable=%d init=%d result=%d",
		msgName,
		msgKey,
		msgDest,
		msgParam1,
		msgParam2,
		msgParam3,
		msgParam4,
		playersNum,
		firstClient,
		reliable,
		init,
		result
	);
	return result;
}
