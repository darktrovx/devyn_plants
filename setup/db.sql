CREATE TABLE `plants` (
	`uuid` VARCHAR(50) NOT NULL COLLATE 'utf8mb4_general_ci',
	`type` VARCHAR(50) NOT NULL COLLATE 'utf8mb4_general_ci',
	`data` TEXT NULL DEFAULT NULL COLLATE 'utf8mb4_general_ci',
	`stage` VARCHAR(255) NULL DEFAULT NULL COLLATE 'utf8mb4_general_ci',
	`plantdate` INT(11) NOT NULL,
	UNIQUE INDEX `uuid` (`uuid`) USING BTREE
)