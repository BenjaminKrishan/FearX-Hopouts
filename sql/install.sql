CREATE TABLE IF NOT EXISTS `fx_hopouts_stats` (
    `identifier` VARCHAR(60) NOT NULL,
    `rating` INT NOT NULL DEFAULT 1000,
    `wins` INT NOT NULL DEFAULT 0,
    `losses` INT NOT NULL DEFAULT 0,
    `kills` INT NOT NULL DEFAULT 0,
    `deaths` INT NOT NULL DEFAULT 0,
    `headshots` INT NOT NULL DEFAULT 0,
    `playtime` INT NOT NULL DEFAULT 0,
    `streak` INT NOT NULL DEFAULT 0,
    `best_streak` INT NOT NULL DEFAULT 0,
    `credits` INT NOT NULL DEFAULT 0,
    `gang` VARCHAR(40) NOT NULL DEFAULT '',
    `name` VARCHAR(80) NOT NULL DEFAULT '',
    `avatar` VARCHAR(255) NOT NULL DEFAULT '',
    `loadout_owned` LONGTEXT NULL,
    `loadout_eq` LONGTEXT NULL,
    PRIMARY KEY (`identifier`),
    KEY `rating` (`rating`),
    KEY `wins` (`wins`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `fx_hopouts_friends` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `a` VARCHAR(60) NOT NULL,
    `b` VARCHAR(60) NOT NULL,
    `status` VARCHAR(10) NOT NULL DEFAULT 'pending',
    `created` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `pair` (`a`, `b`),
    KEY `b` (`b`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `fx_hopouts_inv` (
    `identifier` VARCHAR(60) NOT NULL,
    `items` LONGTEXT NOT NULL,
    `created` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
