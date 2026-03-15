# Changelog

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
