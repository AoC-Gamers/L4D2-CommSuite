# Instalacion

## Requisitos

- SourceMod 1.12 o compatible
- Left 4 Dead 2
- Left4DHooks

Dependencias opcionales:

- `basecomm`
  - provider de restricciones compatible con `l4d2_commguard`
- `sourcecomms++`
  - provider alternativo de restricciones compatible con `l4d2_commguard`
- `bansystem_comm`
  - provider alternativo de restricciones compatible con `l4d2_commguard`
- `geoip.ext`
  - usado por `l4d2_chatlog` para enriquecer joins
- `clientprefs`
  - usado por `l4d2_commrelay` para persistir la preferencia de voz del espectador

## Despliegue minimo

1. Compila los `.sp` a `.smx`.
2. Sube los binarios a `addons/sourcemod/plugins/`.
3. Sube las includes publicas si otro proyecto va a consumir la API.
4. Reinicia el servidor o carga los plugins.

## Autoexec y logs

La suite crea autoexecs en:

- `cfg/sourcemod/l4d2_commsuite/`

Los logs tecnicos quedan en:

- `addons/sourcemod/logs/l4d2_commsuite/`

Ademas, `l4d2_chatlog` genera sus logs funcionales en:

- `addons/sourcemod/logs/chats/`

## Configuraciones recomendadas

### Relay de espectadores

Carga:

- `l4d2_commcore`
- `l4d2_commguard`
- `l4d2_commrelay`

### Filtro de ruido

Carga:

- `l4d2_commcore`
- `l4d2_chatnoise`

### Auditoria

Carga:

- `l4d2_commcore`
- `l4d2_chatlog`

## SQL de chatlog

Si vas a usar auditoria SQL de joins:

1. importa:
   - `addons/sourcemod/configs/sql-init-commsuite/mysql/l4d2_chatlog_joins.sql`
2. configura en `databases.cfg` la entrada que usara `l4d2_chatlog_sql_config`
3. activa:
   - `l4d2_chatlog_sql_enabled 1`
4. define:
   - `l4d2_chatlog_sql_server_id "<server-id>"`

## Orden practico de carga

El orden no necesita ser estricto si las libraries terminan disponibles, pero la forma mas limpia es:

1. `l4d2_commcore`
2. `l4d2_commguard`
3. `l4d2_commrelay`
4. `l4d2_chatnoise`
5. `l4d2_chatlog`

Los satelites toleran carga tardia y reevaluan libraries en `OnAllPluginsLoaded` y `OnLibraryAdded`.
