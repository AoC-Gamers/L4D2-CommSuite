CREATE TABLE IF NOT EXISTS `l4d2_chatlog_joins` (
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
