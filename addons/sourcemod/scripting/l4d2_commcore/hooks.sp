#if defined _l4d2_commcore_hooks_included
	#endinput
#endif
#define _l4d2_commcore_hooks_included

void L4D2Comm_InitHooks()
{
	HookEvent("player_connect", L4D2Comm_Event_PlayerConnect, EventHookMode_Pre);
	HookEvent("player_disconnect", L4D2Comm_Event_PlayerDisconnect, EventHookMode_Pre);
	HookEvent("player_changename", L4D2Comm_Event_PlayerNameChange, EventHookMode_Pre);
	HookEvent("player_team", L4D2Comm_Event_PlayerTeam, EventHookMode_Pre);
	HookEvent("server_cvar", L4D2Comm_Event_ServerCvar, EventHookMode_Pre);

	UserMsg msgId = GetUserMessageId("SayText2");
	if (msgId != INVALID_MESSAGE_ID)
	{
		HookUserMessage(msgId, L4D2Comm_UserMessage_SayText2, true);
	}

	msgId = GetUserMessageId("TextMsg");
	if (msgId != INVALID_MESSAGE_ID)
	{
		HookUserMessage(msgId, L4D2Comm_UserMessage_TextMsg, true);
	}
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	L4D2Comm_Hook(
		"OnClientSayCommand. client=%d valid=%d human=%d command=%s text=%s",
		client,
		L4D2Comm_IsValidClient(client),
		L4D2Comm_IsInGameHuman(client),
		command,
		sArgs
	);
	L4D2CommChannel channel = L4D2Comm_GetChannelForCommand(command);
	Action result = L4D2Comm_CallChatPreForward(client, channel, sArgs);
	if (result >= Plugin_Handled)
	{
		L4D2Comm_QueueSuppressedChatPost(client, channel, sArgs);
		L4D2Comm_CallChatBlockedForward(client, channel, sArgs);
	}
	if (result >= Plugin_Handled)
	{
		L4D2Comm_Hook("Chat pre-forward blocked game call. client=%d command=%s result=%d", client, command, result);
		return result;
	}

	return Plugin_Continue;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	L4D2CommChannel channel = L4D2Comm_GetChannelForCommand(command);
	if (L4D2Comm_TakeSuppressedChatPost(client, channel, sArgs))
	{
		L4D2Comm_Hook("Chat post-forward suppressed. client=%d command=%s", client, command);
		return;
	}

	L4D2Comm_CallChatPostForward(client, channel, sArgs);
}

public Action L4D2Comm_Event_ServerCvar(Event event, const char[] name, bool dontBroadcast)
{
	return L4D2Comm_HandleNoiseEvent_ServerCvar(event);
}

public Action L4D2Comm_Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast)
{
	return L4D2Comm_HandleNoiseEvent_PlayerConnect(event);
}

public Action L4D2Comm_Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	return L4D2Comm_HandleNoiseEvent_PlayerDisconnect(event);
}

public Action L4D2Comm_Event_PlayerNameChange(Event event, const char[] name, bool dontBroadcast)
{
	return L4D2Comm_HandleNoiseEvent_PlayerNameChange(event);
}

public Action L4D2Comm_Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	return L4D2Comm_HandleNoiseEvent_PlayerTeam(event);
}

public Action L4D2Comm_UserMessage_SayText2(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	return L4D2Comm_HandleNoiseUserMessage_SayText2(msg_id, msg, players, playersNum, reliable, init);
}

public Action L4D2Comm_UserMessage_TextMsg(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	return L4D2Comm_HandleNoiseUserMessage_TextMsg(msg_id, msg, players, playersNum, reliable, init);
}
