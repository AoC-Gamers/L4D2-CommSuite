# Changelog

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
