-- MySQL Script generated by MySQL Workbench
-- 10/05/16 10:21:34
-- Model: New Model    Version: 1.0
SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL,ALLOW_INVALID_DATES';

-- -----------------------------------------------------
-- Schema centreon_consolidate_alerts
-- -----------------------------------------------------
CREATE SCHEMA IF NOT EXISTS `centreon_consolidate_alerts` DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci ;
USE `centreon_consolidate_alerts` ;

-- -----------------------------------------------------
-- Table `centreon_consolidate_alerts`.`Alert`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `centreon_consolidate_alerts`.`Alert` (
  `id` INT(11) NOT NULL,
  `host_id` INT(11) NOT NULL COMMENT 'raw_duration : end_time - soft_start_time' /* comment truncated */ /*interpreted_duration : tps reel en prenant compte les downtimes

acknowledgement_id : ref vers la table Acknowledgements
downtime_id : string qui permet de stocker le ou les id des downtimes qui impacte(nt) l'alerte (separateur = espace)*/,
  `host_name` VARCHAR(255) NOT NULL,
  `service_id` INT(11) NOT NULL,
  `service_description` VARCHAR(255) NOT NULL,
  `status` TINYINT NOT NULL,
  `output` TEXT NOT NULL,
  `soft_start_time` INT(11) NULL DEFAULT NULL,
  `hard_start_time` INT(11) NULL DEFAULT NULL,
  `end_time` INT(11) NULL DEFAULT NULL,
  `raw_duration` INT(11) NULL DEFAULT NULL,
  `interpreted_duration` INT(11) NULL DEFAULT NULL,
  `downtime_occurrence` TINYINT NULL DEFAULT NULL,
  `downtime_id` VARCHAR(255) NULL DEFAULT NULL,
  `acknowledgement_id` INT NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `idAlerts_UNIQUE` (`id` ASC))
ENGINE = InnoDB;


SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
