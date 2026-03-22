# Text Chat Flow

Documento de respaldo para la investigacion del flujo de chat textual en Left 4 Dead 2.

## Alcance

Este documento cubre:
- entrada de `say` y `say_team` en servidor
- emision de mensajes de chat hacia clientes
- render de mensajes en cliente
- eventos de ruido que terminan impresos en chat
- puntos de intercepcion recomendados para SourceMod

No cubre voz ni relay de voz.

## Flujo de texto en servidor

Entrada principal:
- [client.cpp](https://github.com/alliedmodders/hl2sdk/blob/l4d2/game/server/client.cpp)

Puntos observados:
- `say` y `say_team` terminan entrando al flujo de `Host_Say(...)`
- el motor aplica validaciones base antes de emitir el mensaje
- existe throttling del habla
- el texto pasa por saneamiento y chequeos de permiso para hablar
- el servidor decide destinatarios segun equipo, estado y reglas del juego

Comportamiento relevante:
- el flujo distingue entre chat publico y chat de equipo
- el servidor termina enviando el mensaje con `UTIL_SayText2Filter(...)` o `UTIL_SayTextFilter(...)`
- despues de emitir el chat, el servidor dispara el evento `player_say`

Implicacion:
- el punto correcto para gobernar `say` y `say_team` en SourceMod es el comando, no el evento `player_say`
- `player_say` llega tarde para tomar control limpio del flujo

## Render de texto en cliente

Entrada principal:
- [hud_basechat.cpp](https://github.com/alliedmodders/hl2sdk/blob/l4d2/game/client/hud_basechat.cpp)

Puntos observados:
- `SayText2` construye el mensaje localizado visible en chat/HUD
- `TextMsg` sigue una ruta separada
- los mensajes recibidos ya vienen con token localizado y parametros

Implicacion:
- `SayText2` sirve para observar o suprimir parte del texto mostrado al cliente
- no debe considerarse la unica fuente de verdad para gobernar el chat de jugadores

## Eventos de ruido impresos en chat

Entrada principal:
- [clientmode_shared.cpp](https://github.com/alliedmodders/hl2sdk/blob/l4d2/game/client/clientmode_shared.cpp)

Eventos relevantes observados:
- `player_connect`
- `player_disconnect`
- `player_team`
- `player_changename`
- `server_cvar`

Comportamiento relevante:
- el cliente imprime estos eventos como mensajes de chat localizados
- `player_team` se usa para mensajes tipo cambio de equipo
- cuando `player_team` tiene `disconnect = true`, el cliente evita imprimir el mensaje de team change

Implicacion:
- el filtrado de ruido debe vivir en hooks de eventos `Pre`
- no conviene intentar resolver todo desde `SayText2`

## Puntos de intercepcion recomendados en SourceMod

Para chat de jugadores:
- `OnClientSayCommand(...)`
- `OnClientSayCommand_Post(...)`
- alternativamente `AddCommandListener(..., "say")`
- alternativamente `AddCommandListener(..., "say_team")`

Para ruido:
- `HookEvent(..., EventHookMode_Pre)` sobre:
  - `player_connect`
  - `player_disconnect`
  - `player_team`
  - `player_changename`
  - `server_cvar`

Para mensajes cliente:
- `HookUserMessage(GetUserMessageId("SayText2"), ..., true)`

## Limite importante de usermessages

Archivo relevante:
- `addons/sourcemod/scripting/include/usermessages.inc`

Punto importante:
- existe `USERMSG_BLOCKHOOKS`

Implicacion:
- un plugin puede emitir un usermessage evitando hooks normales
- por eso `SayText2` no debe ser la base unica de un sistema de control de chat

## Conclusion arquitectonica

Este analisis respalda el diseno actual:
- `l4d2_commcore` es duenio de los hooks centrales
- los satelites no deben hookear `say` o `say_team` por su cuenta
- `l4d2_commrelay` consume el forward post
- `l4d2_commguard` consume el forward pre para restricciones de texto
- `l4d2_chatnoise` consume eventos y usermessages relacionados con ruido

Beneficio:
- un solo hook al hot path del chat
- politicas modulares en plugins pequenos
- menor duplicacion de logica y menor riesgo de conflicto entre plugins

## Modelo de hooks de CommSuite

Para chat de jugadores, `l4d2_commcore` expone tres momentos claros:

- `L4D2Comm_OnChatMessage`
  - pre-hook del hot path
  - si algun plugin devuelve `Plugin_Handled` o `Plugin_Stop`, el chat no se emite
- `L4D2Comm_OnChatMessage_Blocked`
  - post de rechazo
  - sirve para auditoria o reacciones ante mensajes bloqueados
- `L4D2Comm_OnChatMessage_Post`
  - post de exito
  - solo corre si el juego realmente siguio con la emision

Implicacion:
- `commguard` debe seguir validando en `L4D2Comm_OnChatMessage`
- `commrelay` debe seguir observando solo `L4D2Comm_OnChatMessage_Post`
- `chatlog` puede elegir entre auditar mensajes emitidos, mensajes bloqueados o ambos
