# Voice Chat Flow

## Objetivo
Documentar el flujo visible en SDK de la transmision de voz en Source / Left 4 Dead 2, y dejar claro donde encajan las herramientas de SourceMod usadas por `L4D2-CommSuite`.

## Limite de lo que muestra el SDK
El SDK de juego no expone toda la tuberia de captura, codificacion y transporte de audio. La parte visible aqui es:
- inicializacion del sistema de voz en gamerules
- reglas de quien puede escuchar a quien
- sincronizacion de mascaras servidor -> cliente
- interfaz servidor/engine para aplicar la matriz final

Inferencia:
- la captura del microfono, compresion y transporte de paquetes de voz ocurre mayormente en engine/cliente, no en el game DLL visible en `hl2sdk`
- la capa visible desde el game DLL empieza cuando ya hay que decidir permisos de escucha

## Punto de entrada del sistema
En [gamerules.cpp](https://github.com/alliedmodders/hl2sdk/blob/l4d2/game/shared/gamerules.cpp), el constructor de `CGameRules` inicializa el gestor global de voz:

- `GetVoiceGameMgr()->Init(g_pVoiceGameMgrHelper, gpGlobals->maxClients);`

Tambien, en `CGameRules::Think()` se llama en cada frame:

- `GetVoiceGameMgr()->Update(gpGlobals->frametime);`

Y en `CGameRules::ClientCommand(...)` se delegan comandos de voz del cliente:

- `GetVoiceGameMgr()->ClientCommand(...)`

## Nucleo del servidor: `CVoiceGameMgr`
El centro de decision esta en:

- [voice_gamemgr.h](https://github.com/alliedmodders/hl2sdk/blob/l4d2/game/shared/voice_gamemgr.h)
- [voice_gamemgr.cpp](https://github.com/alliedmodders/hl2sdk/blob/l4d2/game/shared/voice_gamemgr.cpp)

Responsabilidades:
- mantener si cada cliente tiene voice del mod habilitada (`g_PlayerModEnable`)
- mantener la mascara de squelch/bloqueo local del cliente (`g_BanMasks`)
- consultar las reglas del juego para saber si un listener puede oir a un talker
- aplicar la matriz final al engine via `IVoiceServer`

### Actualizacion periodica
`CVoiceGameMgr::Update()` no recalcula cada frame inmediatamente. Acumula tiempo y llama a `UpdateMasks()` cada cierto intervalo:

- `m_UpdateInterval += frametime`
- si no se supera `UPDATE_INTERVAL`, no recalcula

Esto significa que el juego ya usa un modelo periodico para reconstruir la matriz de escucha.

### Mascara de escucha final
En `CVoiceGameMgr::UpdateMasks()` ocurre lo importante:

1. lee `sv_alltalk`
2. para cada listener construye `gameRulesMask`
3. para cada talker pregunta:
   - `bAllTalk`
   - o `m_pHelper->CanPlayerHearPlayer(...)`
4. combina eso con `g_BanMasks`
5. envia `VoiceMask` al cliente si hubo cambio
6. aplica al engine:
   - `g_pVoiceServer->SetClientListening(iClient+1, iOtherClient+1, bCanHear);`
   - `g_pVoiceServer->SetClientProximity(...)`

La formula final relevante es:

- `bCanHear = gameRulesMask[iOtherClient] && !g_BanMasks[iClient][iOtherClient]`

Entonces, desde la logica del juego, la escucha final depende de:
- reglas del juego
- `sv_alltalk`
- squelch/bloqueo local del listener

## Reglas del juego: `IVoiceGameMgrHelper`
La interfaz que decide si un jugador puede oir a otro es:

- [voice_gamemgr.h](https://github.com/alliedmodders/hl2sdk/blob/l4d2/game/shared/voice_gamemgr.h)

Metodo:
- `CanPlayerHearPlayer(CBasePlayer *pListener, CBasePlayer *pTalker, bool &bProximity)`

Cada gamerules implementa su helper propio.

Ejemplo SDK genrico:
- [sdk_gamerules.cpp](https://github.com/alliedmodders/hl2sdk/blob/l4d2/game/shared/sdk/sdk_gamerules.cpp)

Regla:
- vivos oyen solo a su equipo
- muertos solo se oyen entre muertos del mismo equipo

En multiplayer base tambien aparece la idea de team-only:
- [multiplay_gamerules.cpp](https://github.com/alliedmodders/hl2sdk/blob/l4d2/game/shared/multiplay_gamerules.cpp)

## Comandos que manda el cliente
En el cliente, `CVoiceStatus::UpdateServerState()` manda comandos al servidor:

- `VModEnable <0|1>`
- `vban <mask...>`

Esto esta en:
- [voice_status.cpp](https://github.com/alliedmodders/hl2sdk/blob/l4d2/game/shared/voice_status.cpp)

Luego el servidor los procesa en:
- `CVoiceGameMgr::ClientCommand(...)`

`VModEnable` controla si el cliente participa en el voice system del mod.
`vban` representa los jugadores squelched por ese cliente.

## Mensajes del servidor al cliente
El servidor usa dos usermessages principales:

- `RequestState`
- `VoiceMask`

Esto tambien se ve en:
- [voice_gamemgr.cpp](https://github.com/alliedmodders/hl2sdk/blob/l4d2/game/shared/voice_gamemgr.cpp)
- [voice_status.cpp](https://github.com/alliedmodders/hl2sdk/blob/l4d2/game/shared/voice_status.cpp)

### `RequestState`
Pide al cliente que reenvie su estado de voz local.

### `VoiceMask`
El cliente recibe:
- mascara de jugadores audibles
- mascara de jugadores bloqueados por el servidor
- estado `mod enable`

Y actualiza su estado local en:
- `CVoiceStatus::HandleVoiceMaskMsg(...)`

## Borde engine
La interfaz que usa el game DLL para decirle al engine quien oye a quien es:

- [ivoiceserver.h](https://github.com/alliedmodders/hl2sdk/blob/l4d2/public/ivoiceserver.h)

Metodos clave:
- `GetClientListening`
- `SetClientListening`
- `SetClientProximity`

Ademas, el engine informa al game DLL cuando un jugador envio un paquete de voz:

- [eiface.h](https://github.com/alliedmodders/hl2sdk/blob/l4d2/public/eiface.h)
- `IServerGameClients::ClientVoice(edict_t *pEdict)`

Inferencia:
- esto confirma que la transmision cruda del audio pertenece a engine/red
- el game DLL se ocupa sobre todo de politica de permisos y sincronizacion de estado

## Encaje con SourceMod
SourceMod expone la capa util para plugins en:

- [sdktools_voice.inc](C:/Users/israe/sourcemodAPI/addons/sourcemod/scripting/include/sdktools_voice.inc)

Herramientas relevantes:
- `SetClientListeningFlags(client, flags)`
- `GetClientListeningFlags(client)`
- `SetListenOverride(receiver, sender, ListenOverride)`
- `GetListenOverride(receiver, sender)`
- forwards `OnClientSpeaking` y `OnClientSpeakingEnd`

### Que significa esto para CommSuite
`L4D2-CommSuite` no necesita reimplementar `VoiceGameMgr`. Lo correcto es:

- dejar que el juego siga calculando su matriz base
- aplicar ajustes finos por plugin usando `SetListenOverride()`

Esto justifica que `l4d2_commrelay` use `SetListenOverride(receiver, sender, ...)` en vez de `VOICE_LISTENALL`:

- es mas preciso
- no pisa todo el comportamiento de voz del listener
- evita ensuciar receptores que no deben ser gestionados por el satelite

## Conclusiones practicas
1. La voz ya tiene un gestor central en el juego: `CVoiceGameMgr`.
2. Las reglas de equipo/vida/proximidad vienen de gamerules via `CanPlayerHearPlayer(...)`.
3. El engine aplica la matriz final con `IVoiceServer`.
4. SourceMod se monta sobre esa capa y permite overrides por par `receiver/sender`.
5. Para satelites como `l4d2_commrelay`, `SetListenOverride()` es la herramienta correcta.
6. Para bloqueos de voz, `l4d2_commguard` tiene sentido como capa reutilizable sobre providers como `BaseComm`, `SourceComms++` o `BanSystem Comm`.
