# Plugins y Dependencias

## l4d2_commcore

Rol:

- runtime base de texto
- engancha `say`, `say_team`, `server_cvar`, `player_connect`, `player_disconnect`, `player_changename`, `player_team`, `SayText2` y `TextMsg`

Comando:

- `sm_l4d2_commcore_status`

ConVars principales:

- `l4d2_commcore_debug_mask`
- `l4d2_commcore_noise_enabled`

Library publica:

- `l4d2_commcore`

## l4d2_commguard

Rol:

- runtime unificado de restricciones de chat y voz
- consulta un provider activo de castigos

Providers soportados:

- `basecomm`
- `sourcecomms++`
- `bansystem_comm`

Comando:

- `sm_l4d2_commguard_status`

ConVars principales:

- `l4d2_commguard_debug_mask`
- `l4d2_commguard_chat_enabled`
- `l4d2_commguard_voice_enabled`

Library publica:

- `l4d2_commguard`

## l4d2_commrelay

Rol:

- relay de chat de equipo a spec/SourceTV
- relay de voz a espectadores

Comandos:

- `sm_hear [on|off|status]`
- `sm_listen [on|off|status]`
- `sm_l4d2_commrelay_status`

ConVars principales:

- `l4d2_commrelay_debug_mask`
- `l4d2_commrelay_chat_enabled`
- `l4d2_commrelay_chat_spec_team`
- `l4d2_commrelay_chat_sourcetv_team`
- `l4d2_commrelay_voice_enabled`
- `l4d2_commrelay_voice_default_enabled`
- `l4d2_commrelay_voice_survivor`
- `l4d2_commrelay_voice_infected`

Dependencias:

- requiere `l4d2_commcore`
- usa `l4d2_commguard` si esta presente
- usa `clientprefs` para guardar la preferencia de voz

Library publica:

- `l4d2_commrelay`

## l4d2_chatnoise

Rol:

- suprime ruido de chat del juego o de SourceMod

Comando:

- `sm_l4d2_chatnoise_status`

ConVars principales:

- `l4d2_chatnoise_debug_mask`
- `l4d2_chatnoise_enabled`
- `l4d2_chatnoise_suppress_player_connect`
- `l4d2_chatnoise_suppress_player_disconnect`
- `l4d2_chatnoise_suppress_player_team`
- `l4d2_chatnoise_suppress_server_cvar`
- `l4d2_chatnoise_suppress_name_change`
- `l4d2_chatnoise_suppress_sm_cvar_change`

Dependencias:

- requiere `l4d2_commcore`

## l4d2_chatlog

Rol:

- escribe auditoria de chat y lifecycle a archivo
- puede escribir joins a MySQL y exponer consultas admin

Comandos:

- `sm_l4d2_chatlog_status`
- `sm_l4d2_chatlog_sql_reconnect`
- `sm_l4d2_chatlog_join_summary`
- `sm_l4d2_chatlog_join_history`
- `sm_l4d2_chatlog_join_related`
- `sm_l4d2_chatlog_join_ip`

ConVars principales:

- `l4d2_chatlog_debug_mask`
- `l4d2_chatlog_enabled`
- `l4d2_chatlog_log_public`
- `l4d2_chatlog_log_team`
- `l4d2_chatlog_log_console`
- `l4d2_chatlog_log_connect`
- `l4d2_chatlog_log_disconnect`
- `l4d2_chatlog_log_name_change`
- `l4d2_chatlog_log_player_team`
- `l4d2_chatlog_detail`
- `l4d2_chatlog_join_audit`
- `l4d2_chatlog_sql_enabled`
- `l4d2_chatlog_sql_config`
- `l4d2_chatlog_sql_server_id`

Dependencias:

- requiere `l4d2_commcore`
- usa `geoip.ext` para pais/IP
- usa MySQL solo si `l4d2_chatlog_sql_enabled = 1`
