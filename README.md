# L4D2-CommSuite

Suite modular de comunicacion para Left 4 Dead 2 sobre SourceMod.

`L4D2-CommSuite` centraliza hooks de chat, relay de texto y voz, guardias de restricciones y auditoria. La idea es evitar que varios plugins enganchen el mismo hot path por separado y, en su lugar, delegar politicas a satelites pequeños.

## Componentes

- `l4d2_commcore`
  - runtime base para hooks de chat y ruido de comunicacion
  - expone la API publica `l4d2_commcore`
- `l4d2_commguard`
  - runtime unificado de restricciones de chat y voz
  - integra `basecomm`, `sourcecomms++` o `bansystem_comm`
- `l4d2_commrelay`
  - relay de chat de equipo a spec/SourceTV
  - relay de voz para espectadores con preferencia por cookie
- `l4d2_chatnoise`
  - filtro opcional de ruido de chat (`player_connect`, `player_disconnect`, `player_team`, `server_cvar`, name change, actividad de `sm_cvar`)
- `l4d2_chatlog`
  - auditoria de chat y lifecycle a archivo
  - auditoria SQL opcional de joins

## Diseño

- `commcore` es el dueño del hot path de texto.
- `commguard` y `commrelay` unifican las capas transversales de restricciones y relay.
- `chatnoise` y `chatlog` siguen como satelites especificos de texto.
- la suite usa una carpeta comun para autoexec y logs:
  - `cfg/sourcemod/l4d2_commsuite/`
  - `addons/sourcemod/logs/l4d2_commsuite/`

## Casos de uso comunes

- Relay de voz y chat para espectadores:
  - `l4d2_commcore`
  - `l4d2_commguard`
  - `l4d2_commrelay`
- Filtro de ruido del chat:
  - `l4d2_commcore`
  - `l4d2_chatnoise`
- Auditoria de chat y joins:
  - `l4d2_commcore`
  - `l4d2_chatlog`

## Documentacion

- [Instalacion](doc/INSTALLATION.md)
- [Plugins y Dependencias](doc/PLUGINS.md)
- [Flujo de chat textual](doc/TEXT_CHAT_FLOW.md)
- [Flujo de voz](doc/VOICE_CHAT_FLOW.md)
- [Auditoria SQL de joins](doc/JOIN_AUDIT_SQL.md)

## SQL

- schema actual:
  - `addons/sourcemod/configs/sql-init-commsuite/mysql/l4d2_chatlog_joins.sql`

## Estado actual

- el core gobierna texto
- la capa de voz vive en satelites
- `commguard` es el runtime unico de restricciones de comunicacion
