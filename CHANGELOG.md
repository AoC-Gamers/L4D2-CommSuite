# Changelog

## Sin versionar

- `l4d2_chatlog`
  - valida el cliente antes de resolver equipo o nombre en callbacks post-chat renderizado
  - evita errores al loguear chat cuando el autor ya no sigue conectado y usa fallback seguro para equipo/nombre
- `l4d2_commguard`
  - corrige el helper compartido `L4D2CS_NormalLogToFileEx` para alinear correctamente `VFormat` con los varargs
  - evita errores `Client index ... is invalid` al loguear cambios de estado de voz con formatos como `client=%N`

## 0.3.0

Ajuste del render de chat y del relay de chat de equipo para `L4D2-CommSuite`.

- `l4d2_commcore`
  - expone version `0.3.0` para la API publica del core
  - integra `localizer` de forma segura, inicializando el runtime y evitando consultas antes de que este listo
  - localiza prompts de chat de equipo en `TextMsg` usando idioma de servidor
  - deja de reconstruir el mensaje completo con las frases `#L4D_Chat_*` y pasa a traducir solo la etiqueta del equipo
  - conserva el formato custom del chat, con nombre en `teamcolor` y etiqueta de equipo sin color
- `l4d2_commrelay`
  - expone version `0.3.0` para la API publica del relay
  - corrige el relay de chat de equipo a spectators y SourceTV/replay alineando el render con `CommCore`
  - inicializa `localizer` de forma segura para evitar fallos en relay cuando las frases aun no estan listas
  - usa etiqueta de equipo traducida por idioma del servidor y conserva el formato custom del chat relayado
- `l4d2_commguard`
  - expone version `0.3.0` para la API publica del guard
- `l4d2_chatnoise`
  - expone version `0.3.0`
- `l4d2_chatlog`
  - expone version `0.3.0`

## 0.2.0

Consolidacion operativa de logging y ajuste de ruido para `L4D2-CommSuite`.

- `l4d2_commcore`
  - expone version `0.2.0` para la API publica del core
  - elimina aliases legacy `L4D2CC_*` y `L4D2ChatChannel*`; la API publica queda solo con `L4D2Comm_*`
- `l4d2_commguard`
  - agrega log normal de startup, provider activo y cambios efectivos de estado de voz
  - elimina logs normales de librerias para reducir ruido
  - evita reloggear cambios de provider cuando el provider activo no cambia realmente
- `l4d2_commrelay`
  - agrega log normal de startup y mantiene eventos funcionales de relay
  - elimina logs normales de librerias y entradas redundantes de scan
- `l4d2_chatnoise`
  - agrega log normal de startup
  - elimina logs normales de librerias y scans redundantes
- `l4d2_chatlog`
  - agrega log normal de startup
  - conserva en log normal solo problemas de base de datos y elimina eventos exitosos o de cierre
- infraestructura comun
  - nuevo modo de log compartido `l4d2_commsuite_log_mode` con `0=off`, `1=normal`, `2=debug`
  - logs normales centralizados en `addons/sourcemod/logs/l4d2_commsuite.log`
  - logs debug por plugin mantenidos en `addons/sourcemod/logs/l4d2_commsuite/`
  - los subdirectorios debug solo se crean cuando el modo global esta en `debug`
  - normal y debug pasan a ser modos mutuamente exclusivos

## 0.1.0

Version inicial de `L4D2-CommSuite`.

- `l4d2_commcore`
  - runtime base para hooks de chat, ruido y API publica
- `l4d2_commguard`
  - runtime unificado de restricciones de chat y voz
  - soporte para `basecomm`, `sourcecomms++` y `bansystem_comm`
- `l4d2_commrelay`
  - relay de chat de equipo a spectators/SourceTV
  - relay de voz para spectators con preferencia persistida
- `l4d2_chatnoise`
  - filtros opcionales para `player_connect`, `player_disconnect`, `player_team`, `server_cvar`, cambios de nombre y actividad de `sm_cvar`
- `l4d2_chatlog`
  - auditoria de chat a archivo
  - auditoria SQL opcional de joins
- infraestructura comun
  - autoexecs en `cfg/sourcemod/l4d2_commsuite/`
  - logs tecnicos en `addons/sourcemod/logs/l4d2_commsuite/`
  - SQL init scripts en `addons/sourcemod/configs/sql-init-commsuite/`
  - workflows de build/release para canales `develop`, `latest` y releases versionadas
