CREATE TABLE IF NOT EXISTS `rossracing_ranking` (
  `circuit` varchar(50) NOT NULL,
  `user_id` int(11) NOT NULL,
  `name` varchar(100) DEFAULT NULL,
  `vehicle` varchar(50) DEFAULT NULL,
  `time` float NOT NULL,
  `date` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`circuit`,`user_id`),
  INDEX `idx_circuit_time` (`circuit`, `time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
