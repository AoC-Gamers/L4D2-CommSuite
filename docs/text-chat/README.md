# Chat de texto

CommCore procesa `say` y `say_team` desde `OnClientSayCommand`. Clasifica
el canal y delega bloqueo, transformación y observación a sus consumidores.

## Ciclo del mensaje

| Fase | Forward público | Decisión |
|---|---|---|
| Permiso | `L4D2Comm_OnChatMessage(client, channel, text)` | `Plugin_Continue` pasa a render. `Plugin_Handled` o `Plugin_Stop` bloquean. |
| Render | `L4D2Comm_OnChatRender(client, channel, prefix, name, text)` | `Plugin_Continue` conserva la emisión del juego. `Plugin_Changed` activa la emisión manual. `Plugin_Handled` o `Plugin_Stop` bloquean. |
| Rechazo | `L4D2Comm_OnChatMessage_Blocked` | Permite auditar el bloqueo. |
| Entrega | `L4D2Comm_OnChatMessage_Post(client, channel, text)` y `L4D2Comm_OnChatMessage_Rendered_Post(client, channel, prefix, name, text)` | El primero indica que el flujo tuvo éxito. El segundo entrega lo que se mostró al jugador. |

Render recibe buffers mutables para prefijo, nombre y texto. El render inicial
usa prefijo vacío, nombre del cliente y texto del comando. Al emitir manualmente,
CommCore aplica los colores y reglas de destinatarios. En chat de equipo usa
`L4D2Comm_ShouldSendTeamChatToTarget` y contempla al autor, espectadores, SourceTV
y Replay según sus reglas. Una cola de supresión por cliente, canal y texto
evita repetir el post del juego para mensajes bloqueados o emitidos manualmente.

## Consumidores

- **CommGuard** decide durante la fase de permiso con el proveedor activo. Comprueba restricciones de clientes humanos válidos.
- **ChatLog** registra la entrega final y, si está habilitado, el rechazo. También audita eventos de conexión y desconexión.
- **CommRelay** consume la entrega final de chat de equipo de autores humanos válidos y la reenvía a los espectadores correspondientes.
- **ChatNoise** consume hooks de eventos del sistema, `SayText2` y `TextMsg`. CommCore observa estas señales en paralelo al flujo de `say` y `say_team`.

Carga CommCore antes de sus consumidores. Usa sus forwards para integrar
satélites a la ruta de chat.

## API pública de CommCore

El contrato está declarado en [addons/sourcemod/scripting/include/l4d2_commcore.inc](../../addons/sourcemod/scripting/include/l4d2_commcore.inc).

Forwards de chat

- `L4D2Comm_OnChatMessage`
- `L4D2Comm_OnChatRender`
- `L4D2Comm_OnChatMessage_Blocked`
- `L4D2Comm_OnChatMessage_Post`
- `L4D2Comm_OnChatMessage_Rendered_Post`

Forwards de ruido

- `L4D2Comm_OnServerCvarMessage`
- `L4D2Comm_OnPlayerConnectMessage`
- `L4D2Comm_OnPlayerDisconnectMessage`
- `L4D2Comm_OnPlayerNameChangeMessage`
- `L4D2Comm_OnPlayerTeamMessage`
- `L4D2Comm_OnTextMsgMessage`
- `L4D2Comm_OnSayText2Message`

Canales

- `L4D2CommChannel_Public`
- `L4D2CommChannel_Team`

## Diagnóstico

| Síntoma | Qué revisar |
|---|---|
| El mensaje no aparece | Comprueba `OnClientSayCommand`, el forward de permiso y el proveedor que usa CommGuard. |
| ChatLog no escribe un mensaje visible | Revisa `L4D2Comm_OnChatMessage_Rendered_Post`, `ShouldLogChat` y el destino del log. |
| El mensaje aparece duplicado | Revisa el resultado de render, la firma de supresión y los plugins que emiten chat fuera de CommCore. |
| Aparece texto fuera del flujo | Revisa `SayText2`, `TextMsg`, eventos de ruido y emisiones directas. |

La implementación está en [hooks.sp](../../addons/sourcemod/scripting/l4d2_commcore/hooks.sp)
y [helpers.sp](../../addons/sourcemod/scripting/l4d2_commcore/helpers.sp).
Consulta la [instalación](../installation/README.md) y la [referencia de plugins](../plugins/README.md).
