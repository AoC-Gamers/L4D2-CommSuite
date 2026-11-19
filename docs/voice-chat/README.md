# Voz

CommGuard resuelve el estado efectivo de bloqueo y CommRelay aplica los
ajustes de escucha para cada par de receptor y emisor con `SetListenOverride`.
Las reglas del juego siguen calculando la matriz base. Consulta
[la configuración de los proveedores](../plugins/README.md#l4d2_commguard).

## API de CommGuard

La suite resuelve restricciones como cambios de estado. El contrato declara estos forwards:

- `L4D2CommGuard_OnVoiceBlockCheck`
  - pre-check para proveedores o satelites externos
  - `Plugin_Handled` fuerza estado bloqueado
- `L4D2CommGuard_OnVoiceBlockResolved`
  - post de resolución
  - corre en cada recálculo del estado
  - informa `blocked` y si hubo `changed`
- `L4D2CommGuard_OnClientVoiceBlockChanged`
  - post de delta real
  - solo corre cuando cambia el estado cacheado

## Matriz de escucha

`CGameRules` inicializa y actualiza `CVoiceGameMgr`. El gestor usa
`sv_alltalk` o `CanPlayerHearPlayer` para construir la máscara de reglas por
receptor, y la combina con `g_BanMasks`. El motor aplica la escucha y
proximidad mediante `IVoiceServer`. El SDK público de juego describe esta
matriz y deja el transporte de audio en el motor.

El cliente comunica participación y silencios locales mediante
`VModEnable` y `vban`. `RequestState` solicita el estado y `VoiceMask` devuelve
las máscaras de escucha y bloqueo junto con el estado del módulo.

SourceMod expone `SetClientListeningFlags`, `GetClientListeningFlags`,
`SetListenOverride`, `GetListenOverride`, `OnClientSpeaking` y
`OnClientSpeakingEnd` en `sdktools_voice.inc`. CommRelay aplica ajustes por
receptor y emisor para conservar las reglas de los demás pares.

- [Gestor de voz del juego](https://github.com/alliedmodders/hl2sdk/blob/l4d2/game/shared/voice_gamemgr.cpp)
- [Estado de voz del cliente](https://github.com/alliedmodders/hl2sdk/blob/l4d2/game/shared/voice_status.cpp)
- [Interfaces del motor](https://github.com/alliedmodders/hl2sdk/blob/l4d2/public/eiface.h)
