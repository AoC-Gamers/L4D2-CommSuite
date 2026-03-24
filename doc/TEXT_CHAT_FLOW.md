# Text Chat Flow

Documento tecnico de referencia para el flujo de chat textual en CommSuite.

Objetivo:
- describir el flujo real que usa CommSuite hoy
- identificar con precision por donde interviene cada plugin satelite
- dejar una guia de diagnostico suficiente para no tener que reabrir el SDK de L4D2 o el core de SourceMod cada vez que aparezca una anomalia

Este documento describe el estado actual del repositorio. Si cambia la API publica de CommCore, este archivo debe actualizarse junto con [addons/sourcemod/scripting/include/l4d2_commcore.inc](../addons/sourcemod/scripting/include/l4d2_commcore.inc).

## Alcance

Este documento cubre:
- entrada de `say` y `say_team`
- decision de bloqueo antes de que el juego emita el chat
- etapa de transformacion y render alternativo
- post exitoso del chat final
- filtrado de ruido textual relacionado con eventos y usermessages
- responsabilidad concreta de cada plugin de CommSuite

Este documento no cubre:
- voz y relay de voz
- HUD no textual fuera de `TextMsg` o `SayText2`
- detalles internos del motor de L4D2 mas alla de lo necesario para entender el contrato que consume CommSuite

## Resumen Ejecutivo

La fuente canonica de control para el chat de jugadores en CommSuite es el comando, no el evento `player_say` ni el usermessage `SayText2`.

El flujo operativo correcto es:
1. el jugador ejecuta `say` o `say_team`
2. SourceMod entra a `OnClientSayCommand(...)`
3. `l4d2_commcore` clasifica el canal y llama el forward pre `L4D2Comm_OnChatMessage`
4. si algun consumidor devuelve `Plugin_Handled` o `Plugin_Stop`, el chat queda bloqueado
5. si nadie bloquea, `l4d2_commcore` construye un render por defecto y llama `L4D2Comm_OnChatRender`
6. si algun consumidor devuelve `Plugin_Changed`, el core suprime la emision del juego y emite el chat renderizado manualmente
7. si nadie transforma ni bloquea, el juego sigue su camino normal
8. en ambos caminos exitosos, CommCore termina disparando `L4D2Comm_OnChatMessage_Rendered_Post`

Consecuencia practica:
- `L4D2Comm_OnChatMessage` es el punto de gobierno
- `L4D2Comm_OnChatRender` es el punto de transformacion
- `L4D2Comm_OnChatMessage_Blocked` es el punto de auditoria de rechazo
- `L4D2Comm_OnChatMessage_Rendered_Post` es el punto de auditoria de salida final

## Componentes Involucrados

### CommCore

Archivo principal:
- [addons/sourcemod/scripting/l4d2_commcore.sp](../addons/sourcemod/scripting/l4d2_commcore.sp)

Implementacion del flujo:
- [addons/sourcemod/scripting/l4d2_commcore/hooks.sp](../addons/sourcemod/scripting/l4d2_commcore/hooks.sp)
- [addons/sourcemod/scripting/l4d2_commcore/helpers.sp](../addons/sourcemod/scripting/l4d2_commcore/helpers.sp)

Responsabilidad:
- centralizar hooks de chat y ruido
- definir la API publica de forwards
- decidir si el juego sigue su camino normal o si el core emite un render manual

### ChatLog

Archivo principal:
- [addons/sourcemod/scripting/l4d2_chatlog.sp](../addons/sourcemod/scripting/l4d2_chatlog.sp)

Responsabilidad:
- auditar chat final renderizado
- auditar chat bloqueado si la configuracion lo habilita
- auditar eventos de ciclo de vida y joins

### CommGuard

Archivo principal:
- [addons/sourcemod/scripting/l4d2_commguard.sp](../addons/sourcemod/scripting/l4d2_commguard.sp)

Responsabilidad:
- decidir si un cliente puede hablar o no
- delegar en providers externos como BanSystem Comm, SourceComms++ o BaseComm
- consumir el forward pre de chat para bloquear antes de la emision

### CommRelay

Archivo principal:
- [addons/sourcemod/scripting/l4d2_commrelay.sp](../addons/sourcemod/scripting/l4d2_commrelay.sp)

Responsabilidad:
- observar el chat de equipo ya renderizado
- reenviarlo a espectadores segun las reglas del plugin
- no gobierna la validez del mensaje original

### ChatNoise

Archivo principal:
- [addons/sourcemod/scripting/l4d2_chatnoise.sp](../addons/sourcemod/scripting/l4d2_chatnoise.sp)

Responsabilidad:
- suprimir mensajes de ruido que llegan por eventos o usermessages
- no es el punto de control del chat emitido por jugadores

## API Publica de CommCore

La definicion canonica esta en [addons/sourcemod/scripting/include/l4d2_commcore.inc](../addons/sourcemod/scripting/include/l4d2_commcore.inc).

Forwards de chat relevantes:
- `L4D2Comm_OnChatMessage`
- `L4D2Comm_OnChatRender`
- `L4D2Comm_OnChatMessage_Blocked`
- `L4D2Comm_OnChatMessage_Post`
- `L4D2Comm_OnChatMessage_Rendered_Post`

Forwards de ruido relevantes:
- `L4D2Comm_OnServerCvarMessage`
- `L4D2Comm_OnPlayerConnectMessage`
- `L4D2Comm_OnPlayerDisconnectMessage`
- `L4D2Comm_OnPlayerNameChangeMessage`
- `L4D2Comm_OnPlayerTeamMessage`
- `L4D2Comm_OnTextMsgMessage`
- `L4D2Comm_OnSayText2Message`

Canales de chat expuestos por el core:
- `L4D2CommChannel_Public`
- `L4D2CommChannel_Team`

## Flujo Canonico del Chat

### 1. Entrada por comando

Punto de entrada:
- [addons/sourcemod/scripting/l4d2_commcore/hooks.sp](../addons/sourcemod/scripting/l4d2_commcore/hooks.sp)

Funcion relevante:
- `OnClientSayCommand(int client, const char[] command, const char[] sArgs)`

Hechos importantes:
- CommCore no usa `player_say` como origen de verdad
- el canal se resuelve desde el nombre del comando mediante `L4D2Comm_GetChannelForCommand(...)`
- `say_team` se clasifica como `L4D2CommChannel_Team`
- cualquier otro comando del hot path de chat se trata como publico

Diagnostico:
- si un mensaje visible en pantalla no pasa por `OnClientSayCommand`, el flujo ya no esta transitando por el contrato que CommSuite gobierna
- en ese escenario, revisar wrappers, plugins que reemiten mensajes o rutas de usermessage fuera del hot path normal

### 2. Fase pre: control de permiso

Implementacion:
- `L4D2Comm_CallChatPreForward(...)` en [addons/sourcemod/scripting/l4d2_commcore/helpers.sp](../addons/sourcemod/scripting/l4d2_commcore/helpers.sp)

Contrato:
- CommCore dispara `L4D2Comm_OnChatMessage(client, channel, text)`

Semantica:
- `Plugin_Continue`: el mensaje sigue vivo
- `Plugin_Handled`: se bloquea el chat
- `Plugin_Stop`: tambien se bloquea el chat

Acciones internas de CommCore cuando hay bloqueo:
- marca una firma interna en la cola de suppressions para que el post del juego no duplique el flujo
- dispara `L4D2Comm_OnChatMessage_Blocked(...)`
- devuelve al juego el resultado bloqueante

Consumidor principal actual:
- [addons/sourcemod/scripting/l4d2_commguard.sp](../addons/sourcemod/scripting/l4d2_commguard.sp)

Funcion relevante en CommGuard:
- `public Action L4D2Comm_OnChatMessage(...)`

Decision real de CommGuard:
- solo considera clientes humanos validos
- verifica si el provider activo bloquea el chat del cliente
- si el provider externo responde que el cliente no puede hablar, CommGuard devuelve `Plugin_Handled`

Interpretacion operativa:
- si un mensaje no aparece en chat y ChatLog registra un bloqueado, la autoridad de rechazo estuvo en esta fase

### 3. Fase render: transformacion opcional

Implementacion:
- `L4D2Comm_CallChatRenderForward(...)` en [addons/sourcemod/scripting/l4d2_commcore/helpers.sp](../addons/sourcemod/scripting/l4d2_commcore/helpers.sp)

Buffers mutables del core:
- `prefix`
- `name`
- `text`

Render por defecto generado por CommCore:
- `prefix = ""`
- `name = %N`
- `text = sArgs`

Contrato:
- CommCore llama `L4D2Comm_OnChatRender(client, channel, prefix, name, text)`

Semantica:
- `Plugin_Continue`: el juego sigue con el mensaje original
- `Plugin_Changed`: el core emite manualmente el mensaje transformado y bloquea el camino normal del juego
- `Plugin_Handled` o `Plugin_Stop`: el mensaje queda bloqueado

Implicacion arquitectonica:
- cualquier personalizacion de prefijo, nombre o texto debe vivir aqui
- este es el punto correcto para etiquetas, prefijos VIP, normalizacion o decoracion
- no es correcto modificar la identidad final del chat desde `Rendered_Post`, porque ahi el mensaje ya esta resuelto

### 4. Emision manual cuando hay transformacion

Implementacion:
- `L4D2Comm_EmitRenderedChat(...)` en [addons/sourcemod/scripting/l4d2_commcore/helpers.sp](../addons/sourcemod/scripting/l4d2_commcore/helpers.sp)

Comportamiento:
- imprime una linea equivalente en servidor para diagnostico
- construye el string final con colores
- para chat publico, lo envia a todos los destinos elegibles
- para chat de equipo, respeta `L4D2Comm_ShouldSendTeamChatToTarget(...)`

Reglas del chat de equipo:
- espectadores pueden ver chat de survivor o infected segun el criterio del core
- el autor siempre es destinatario
- SourceTV y Replay son considerados receptores validos

Diagnostico:
- si un plugin devuelve `Plugin_Changed`, el mensaje visible ya no depende del render original del juego
- el post exitoso sigue existiendo, pero pasa a ser producto del core y no del motor

### 5. Post del juego cuando el flujo no fue suprimido

Implementacion:
- `OnClientSayCommand_Post(...)` en [addons/sourcemod/scripting/l4d2_commcore/hooks.sp](../addons/sourcemod/scripting/l4d2_commcore/hooks.sp)

Proteccion contra duplicados:
- CommCore mantiene una cola de suppressions con firmas `client|channel|text`
- si la firma existe, el post del juego se descarta para evitar doble notificacion

Esto protege dos casos:
- mensajes bloqueados en el pre
- mensajes transformados y emitidos manualmente por el core

### 6. Posts publicos de CommCore

Post textual simple:
- `L4D2Comm_OnChatMessage_Post(client, channel, text)`

Post final renderizado:
- `L4D2Comm_OnChatMessage_Rendered_Post(client, channel, prefix, name, text)`

Diferencia conceptual:
- `Post` indica que el flujo de chat sobrevivio
- `Rendered_Post` describe el mensaje final visible que debe usar cualquier consumidor que audite salida real

Regla operativa:
- si el consumidor necesita el mensaje tal como termino en pantalla, debe usar `Rendered_Post`
- si el consumidor necesita solo saber que el chat sobrevivio, `Post` puede ser suficiente

## Donde Interviene Cada Plugin de CommSuite

### CommCore

Interviene en:
- comando de entrada
- decision de bloqueo
- decision de transformacion
- emision manual cuando corresponde
- posts finales
- eventos y usermessages de ruido

No debe asumir:
- politicas de moderacion especificas
- logica de relay de espectadores
- persistencia o auditoria detallada

### CommGuard

Interviene en:
- `L4D2Comm_OnChatMessage`

No interviene en:
- render del mensaje
- usermessages finales
- persistencia del log de chat

Interpretacion:
- CommGuard es una politica de autorizacion, no un renderer ni un logger

### ChatLog

Interviene en:
- `L4D2Comm_OnChatMessage_Rendered_Post`
- `L4D2Comm_OnChatMessage_Blocked`
- eventos de lifecycle como `player_disconnect`

Interpretacion:
- ChatLog no decide si el mensaje vive o muere
- ChatLog observa el resultado final del pipeline y lo persiste

### CommRelay

Interviene en:
- `L4D2Comm_OnChatMessage_Rendered_Post`

Comportamiento:
- solo toma chat de equipo
- solo para autores humanos validos
- lo reenvia a espectadores segun el equipo del autor

Interpretacion:
- CommRelay no crea la verdad del mensaje original
- CommRelay consume una salida ya aceptada y ya renderizada

### ChatNoise

Interviene en:
- `L4D2Comm_OnSayText2Message`
- `L4D2Comm_OnTextMsgMessage`
- forwards de eventos de ruido

Interpretacion:
- ChatNoise no es la capa de control del `say` o `say_team`
- ChatNoise limpia el canal visual de mensajes accesorios o de sistema

## Ruido Textual y Por Que No Debe Mezclarse con el Chat de Jugadores

El flujo de ruido existe en paralelo al chat de jugadores.

Origenes principales:
- eventos del servidor como `player_connect`, `player_disconnect`, `player_team`, `player_changename`, `server_cvar`
- usermessages `SayText2` y `TextMsg`

CommCore engancha ambos tipos en modo `Pre` en [addons/sourcemod/scripting/l4d2_commcore/hooks.sp](../addons/sourcemod/scripting/l4d2_commcore/hooks.sp).

ChatNoise consume esos forwards porque muchos mensajes visibles en HUD o chat no vienen de `say` ni `say_team`, sino de eventos localizados o mensajes del sistema.

Conclusiones operativas:
- un problema en `SayText2` no implica necesariamente un problema en el flujo de `say`
- un mensaje visible en pantalla puede ser ruido textual y no un chat de jugador
- el diagnostico siempre debe distinguir entre `input chat path` y `noise path`

## Que Significa Cada Sintoma

### Sintoma 1: el jugador escribe, pero nadie ve el mensaje

Revisar en este orden:
1. `OnClientSayCommand(...)`
2. `L4D2Comm_OnChatMessage`
3. `L4D2Comm_OnChatMessage_Blocked`
4. provider activo de CommGuard

Conclusiones tipicas:
- si entra al pre y se bloquea, es politica
- si no entra al pre, la ruta de entrada ya no es la canonica de CommSuite

### Sintoma 2: el jugador escribe, el mensaje se ve, pero ChatLog no lo registra

Revisar en este orden:
1. `OnClientSayCommand_Post(...)`
2. `L4D2Comm_OnChatMessage_Rendered_Post`
3. `ShouldLogChat(...)` en ChatLog
4. escritura fisica del archivo de log

Conclusiones tipicas:
- si `Rendered_Post` no corre, el corte esta en CommCore
- si `Rendered_Post` corre y no se escribe, el corte esta en ChatLog o en el target de escritura

### Sintoma 3: el mensaje se ve duplicado

Revisar:
1. si algun plugin esta devolviendo `Plugin_Changed` en render
2. si la suppression queue no coincide con el texto final
3. si existe un plugin externo reemitiendo el chat por fuera del pipeline

### Sintoma 4: aparece texto en pantalla sin pasar por CommSuite

Revisar:
1. `SayText2`
2. `TextMsg`
3. eventos de ruido
4. plugins externos que usan emisiones directas con hooks bloqueados

## Supuestos Operativos que Deben Mantenerse

### Orden de carga

CommCore debe cargarse antes que sus consumidores.

Orden recomendado:
1. `l4d2_commcore.smx`
2. `l4d2_chatlog.smx`
3. `l4d2_chatnoise.smx`
4. `l4d2_commguard.smx`
5. `l4d2_commrelay.smx`

Si los consumidores cargan sin CommCore, pueden quedar sin la biblioteca o sin forwards disponibles durante una ventana de tiempo.

### Un solo dueño del hot path

CommSuite asume que `say` y `say_team` se gobiernan centralmente desde CommCore.

No se recomienda:
- que cada satelite use `AddCommandListener` por su cuenta
- que ChatLog o CommRelay hookeen el comando directamente
- que ChatNoise intente gobernar el contenido de chat de jugadores desde usermessages

Si se rompe esta regla:
- aumenta el riesgo de doble manejo
- se vuelve ambiguo el origen real de un bloqueo o una reemision
- el diagnostico deja de ser lineal

## Mapa Rapido de Archivos para Diagnostico

Entrada y orquestacion:
- [addons/sourcemod/scripting/l4d2_commcore/hooks.sp](../addons/sourcemod/scripting/l4d2_commcore/hooks.sp)

Helpers de render, suppression y dispatch:
- [addons/sourcemod/scripting/l4d2_commcore/helpers.sp](../addons/sourcemod/scripting/l4d2_commcore/helpers.sp)

API publica:
- [addons/sourcemod/scripting/include/l4d2_commcore.inc](../addons/sourcemod/scripting/include/l4d2_commcore.inc)

Bloqueo de chat:
- [addons/sourcemod/scripting/l4d2_commguard.sp](../addons/sourcemod/scripting/l4d2_commguard.sp)

Auditoria y logs:
- [addons/sourcemod/scripting/l4d2_chatlog.sp](../addons/sourcemod/scripting/l4d2_chatlog.sp)

Relay a espectadores:
- [addons/sourcemod/scripting/l4d2_commrelay.sp](../addons/sourcemod/scripting/l4d2_commrelay.sp)

Filtrado de ruido:
- [addons/sourcemod/scripting/l4d2_chatnoise.sp](../addons/sourcemod/scripting/l4d2_chatnoise.sp)

## Regla Final de Mantenimiento

Si se reporta un fallo en el flujo de chat, la investigacion debe empezar aqui y no en el SDK.

Orden de lectura recomendado:
1. este documento
2. `l4d2_commcore.inc`
3. `l4d2_commcore/hooks.sp`
4. el satelite afectado

Solo si el comportamiento observado contradice este contrato tiene sentido bajar al SDK de L4D2 o al core de SourceMod.

Mientras este contrato siga siendo correcto, CommSuite debe poder diagnosticarse y mantenerse desde su propia superficie publica.
