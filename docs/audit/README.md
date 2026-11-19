# Join Audit SQL

Propuesta inicial para persistir `join audit` de `l4d2_chatlog` en MySQL.

## Objetivo

Registrar joins con suficiente contexto para:
- estadisticas de actividad
- busqueda de cuentas relacionadas por IP
- evidencia historica de uso reiterado de una misma IP por distintas cuentas

No esta pensado para tomar decisiones automaticas por si solo. La IP es dinamica y debe tratarse como evidencia auxiliar, no concluyente.

## Tabla sugerida

```sql
CREATE TABLE `l4d2_chatlog_joins` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `joined_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `server_id` VARCHAR(64) NOT NULL DEFAULT '',
    `player_name` VARCHAR(128) NOT NULL DEFAULT '',
    `steamid64` VARCHAR(32) NOT NULL DEFAULT '',
    `accountid` INT UNSIGNED NOT NULL DEFAULT 0,
    `ip_address` VARCHAR(45) NOT NULL DEFAULT '',
    `country` VARCHAR(64) NOT NULL DEFAULT '',
    PRIMARY KEY (`id`),
    KEY `idx_l4d2_chatlog_joins_joined_at` (`joined_at`),
    KEY `idx_l4d2_chatlog_joins_steamid64` (`steamid64`),
    KEY `idx_l4d2_chatlog_joins_accountid` (`accountid`),
    KEY `idx_l4d2_chatlog_joins_ip_address` (`ip_address`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

## Campos recomendados

- `server_id`
  - identifica el gameserver
  - evita mezclar datos de 13 servidores sin contexto
- `steamid64`, `accountid`
  - cubren la identidad suficiente sin duplicar `steamid2`
- `ip_address`
  - evidencia auxiliar
- `country`
  - sirve para filtros blandos y revision manual

## Consultas utiles

### 1. Ultimos joins de una cuenta

```sql
SELECT
    `joined_at`,
    `server_id`,
    `player_name`,
    `steamid64`,
    `accountid`,
    `ip_address`,
    `country`
FROM `l4d2_chatlog_joins`
WHERE `steamid64` = '76561198008295809'
ORDER BY `joined_at` DESC
LIMIT 100;
```

### 2. Distintas cuentas vistas con la misma IP

```sql
SELECT
    `ip_address`,
    COUNT(DISTINCT `steamid64`) AS `distinct_accounts`,
    MIN(`joined_at`) AS `first_seen`,
    MAX(`joined_at`) AS `last_seen`
FROM `l4d2_chatlog_joins`
WHERE `ip_address` <> ''
GROUP BY `ip_address`
HAVING COUNT(DISTINCT `steamid64`) > 1
ORDER BY `distinct_accounts` DESC, `last_seen` DESC;
```

### 3. Cuentas relacionadas a una IP en un periodo prolongado

```sql
SELECT
    `ip_address`,
    `steamid64`,
    MIN(`joined_at`) AS `first_seen`,
    MAX(`joined_at`) AS `last_seen`,
    COUNT(*) AS `joins_count`
FROM `l4d2_chatlog_joins`
WHERE `ip_address` = '190.12.34.56'
GROUP BY `ip_address`, `steamid64`
HAVING TIMESTAMPDIFF(DAY, MIN(`joined_at`), MAX(`joined_at`)) >= 7
ORDER BY `last_seen` DESC;
```

### 4. Posibles relaciones por IP compartida entre cuentas

```sql
SELECT
    a.`steamid64` AS `steamid64_a`,
    b.`steamid64` AS `steamid64_b`,
    a.`ip_address`,
    MIN(LEAST(a.`joined_at`, b.`joined_at`)) AS `first_overlap`,
    MAX(GREATEST(a.`joined_at`, b.`joined_at`)) AS `last_overlap`,
    COUNT(*) AS `overlap_count`
FROM `l4d2_chatlog_joins` a
JOIN `l4d2_chatlog_joins` b
    ON a.`ip_address` = b.`ip_address`
   AND a.`steamid64` < b.`steamid64`
WHERE a.`ip_address` <> ''
GROUP BY a.`steamid64`, b.`steamid64`, a.`ip_address`
HAVING COUNT(*) >= 3
ORDER BY `overlap_count` DESC, `last_overlap` DESC;
```

### 5. Cuentas vistas en una IP concreta

```sql
SELECT
    `accountid`,
    `steamid64`,
    MAX(`player_name`) AS `player_name`,
    COUNT(*) AS `joins_count`,
    MIN(`joined_at`) AS `first_seen`,
    MAX(`joined_at`) AS `last_seen`,
    MAX(`country`) AS `country`
FROM `l4d2_chatlog_joins`
WHERE `ip_address` = '190.12.34.56'
  AND `joined_at` >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY `accountid`, `steamid64`
ORDER BY `joins_count` DESC, `last_seen` DESC
LIMIT 25;
```

## Recomendacion operativa

- usar esta tabla como auditoria, no como sistema de castigo automatico
- agregar `server_id` desde el plugin antes de insert
- si despues se implementa en runtime, hacerlo con inserts async y opcional por cvar
- las consultas de analitica pueden vivir en comandos del plugin
  - por ejemplo con parametros para:
    - ventana de tiempo
    - minimo de coincidencias
    - `server_id`
    - una IP o cuenta concreta
- como no son consultas recurrentes, no hace falta precomputarlas ni mantener timers dedicados

## Comandos pensados en el plugin

- `sm_l4d2_chatlog_join_summary <target|accountid|steamid64> [days] [server_id]`
- `sm_l4d2_chatlog_join_history <target|accountid|steamid64> [limit] [server_id]`
- `sm_l4d2_chatlog_join_related <target|accountid|steamid64> [days] [min_shared] [limit] [server_id]`
- `sm_l4d2_chatlog_join_ip <ip> [days] [limit] [server_id]`

Usar `all` o `*` como `server_id` para consultar sin filtro de servidor.
