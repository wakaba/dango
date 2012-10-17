CREATE TABLE `storage_set` (
  storage_set_id BIGINT UNSIGNED NOT NULL,
  storage_set_name VARBINARY(255) NOT NULL,
  created DOUBLE NOT NULL DEFAULT 0,
  PRIMARY KEY (storage_set_id),
  UNIQUE KEY (storage_set_name),
  KEY (created)
) DEFAULT CHARSET=BINARY;

CREATE TABLE `storage_unit_set` (
  storage_unit_set_id BIGINT UNSIGNED NOT NULL,
  storage_id BIGINT UNSIGNED NOT NULL,
  storage_unit_type SMALLINT UNSIGNED NOT NULL,
  storage_unit_set_name VARBINARY(255) NOT NULL,
  created DOUBLE NOT NULL,
  PRIMARY KEY (storage_unit_set_id),
  UNIQUE KEY (storage_id, storage_unit_type, storage_unit_set_name),
  KEY (created),
  KEY (storage_unit_set, created)
) DEFAULT CHARSET=BINARY;

CREATE TABLE `data_center` (
  data_center_id BIGINT UNSIGNED NOT NULL,
  data_center_name VARBINARY(255) NOT NULL,
  created DOUBLE NOT NULL DEFAULT 0,
  PRIMARY KEY (data_center_id),
  UNIQUE KEY (data_center_name),
  KEY (created)
) DEFAULT CHARSET=BINARY;

CREATE TABLE `table` (
  table_id BIGINT UNSIGNED NOT NULL,
  storage_set_id BIGINT UNSIGNED NOT NULL,
  `table_name` VARBINARY(255) NOT NULL,
  created DOUBLE NOT NULL DEFAULT 0,
  PRIMARY KEY (table_id),
  UNIQUE KEY (storage_set_id, table_name),
  KEY (created)
) DEFAULT CHARSET=BINARY;

CREATE TABLE table_prop (
  table_id BIGINT UNSIGNED NOT NULL,
  storage_set_id BIGINT UNSIGNED NOT NULL,
  storage_unit_type SMALLINT UNSIGNED NOT NULL,
  storage_unit_id BIGINT UNSIGNED NOT NULL,
  created DOUBLE NOT NULL DEFAULT 0,
  PRIMARY KEY (table_id, storage_unit_type),
  KEY (storage_set_id, storage_unit_type, created),
  KEY (storage_unit_id, created),
  KEY (created)
) DEFAULT CHARSET=BINARY;

CREATE TABLE `role` (
  role_id BIGINT UNSIGNED NOT NULL,
  role_name VARBINARY(255) NOT NULL,
  created DOUBLE NOT NULL DEFAULT 0,
  PRIMARY KEY (role_id),
  UNIQUE KEY (role_name),
  KEY (created)
) DEFAULT CHARSET=BINARY;

CREATE TABLE `role_table_status` (
  role_id BIGINT UNSIGNED NOT NULL,
  storage_set_id BIGINT UNSIGNED NOT NULL,
  table_id BIGINT UNSIGNED NOT NULL,
  status SMALLINT UNSIGNED NOT NULL,
  created DOUBLE NOT NULL DEFAULT 0,
  updated DOUBLE NOT NULL DEFAULT 0,
  PRIMARY KEY (role_id, table_id),
  KEY (storage_set_id, table_id, created),
  KEY (created),
  KEY (updated)
) DEFAULT CHARSET=BINARY;

CREATE TABLE `object_data` (
  object_id BIGINT UNSIGNED NOT NULL,
  `name` VARBINARY(255) NOT NULL,
  `value` MEDIUMBLOB,
  created DOUBLE NOT NULL DEFAULT 0,
  updated DOUBLE NOT NULL DEFAULT 0,
  PRIMARY KEY (`object_id`, `name`),
  KEY (created),
  KEY (updated)
) DEFAULT CHARSET=BINARY;
