-- Configuration de la base de données et des tables

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- 1. Salles
CREATE TABLE IF NOT EXISTS `salles` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `nom` VARCHAR(100) NOT NULL,
    `capacite` INT DEFAULT 0,
    `description` TEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2. Types de Place (Standard, VIP, etc.)
CREATE TABLE IF NOT EXISTS `types_place` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `nom` VARCHAR(50) NOT NULL,
    `coefficient_prix` DECIMAL(5, 2) DEFAULT 1.00 COMMENT 'Multiplicateur du prix de base'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3. Places
CREATE TABLE IF NOT EXISTS `places` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `salle_id` INT NOT NULL,
    `rangee` VARCHAR(10) NOT NULL,
    `numero` INT NOT NULL,
    `type_place_id` INT NOT NULL,
    FOREIGN KEY (`salle_id`) REFERENCES `salles`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`type_place_id`) REFERENCES `types_place`(`id`),
    UNIQUE KEY `uk_place_position` (`salle_id`, `rangee`, `numero`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4. Catégories d'Événement
CREATE TABLE IF NOT EXISTS `categories_evenement` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `nom` VARCHAR(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 5. Événements
CREATE TABLE IF NOT EXISTS `evenements` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `titre` VARCHAR(255) NOT NULL,
    `description` TEXT,
    `categorie_id` INT NOT NULL,
    `salle_id` INT NOT NULL,
    `date_debut` DATETIME NOT NULL,
    `date_fin` DATETIME NOT NULL,
    `prix_base` DECIMAL(10, 2) NOT NULL,
    `places_vendues` INT DEFAULT 0,
    `statut` ENUM('Actif', 'Annulé', 'Archivé') DEFAULT 'Actif',
    FOREIGN KEY (`categorie_id`) REFERENCES `categories_evenement`(`id`),
    FOREIGN KEY (`salle_id`) REFERENCES `salles`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 6. Clients
CREATE TABLE IF NOT EXISTS `clients` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `nom` VARCHAR(100) NOT NULL,
    `email` VARCHAR(150) NOT NULL UNIQUE,
    `telephone` VARCHAR(20)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 7. Réservations
-- Statut: 'Confirmée' (payée/validée), 'Annulée'.
CREATE TABLE IF NOT EXISTS `reservations` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `client_id` INT NOT NULL,
    `evenement_id` INT NOT NULL,
    `place_id` INT NOT NULL,
    `date_reservation` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `statut` ENUM('Confirmée', 'Annulée') DEFAULT 'Confirmée',
    FOREIGN KEY (`client_id`) REFERENCES `clients`(`id`),
    FOREIGN KEY (`evenement_id`) REFERENCES `evenements`(`id`),
    FOREIGN KEY (`place_id`) REFERENCES `places`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Contrainte d'unicité pour empêcher la surréservation (Overbooking)
-- Une place ne peut pas avoir deux réservations 'Confirmée' pour le même événement.
-- Note: MariaDB/MySQL ignore NULL dans les contraintes UNIQUE, mais ici statut n'est pas NULL.
-- Cependant, on veut autoriser plusieurs 'Annulée' mais une seule 'Confirmée'.
-- La contrainte UNIQUE standard ne permet pas de filtrer (WHERE statut='Confirmée').
-- On gérera cela principalement via Trigger ou Application, mais pour une contrainte pure SGBD:
-- On peut utiliser un index UNIQUE sur (evenement_id, place_id) si on supprime physiquement les annulations,
-- ou on accepte que l'historique des annulations soit dans une table d'archive.
-- SOLUTION ROBUSTE: Création d'un index UNIQUE fonctionnel ou via un TRIGGER.
-- MariaDB 11 supporte les index sur des colonnes virtuelles.
-- Ajoutons une colonne virtuelle pour l'unicité.

ALTER TABLE `reservations`
ADD COLUMN `verrou_reservation` VARCHAR(255) AS (IF(statut = 'Confirmée', CONCAT(evenement_id, '-', place_id), NULL)) PERSISTENT;

ALTER TABLE `reservations`
ADD UNIQUE INDEX `uk_reservation_active` (`verrou_reservation`);


-- 8. Paiements
CREATE TABLE IF NOT EXISTS `paiements` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `reservation_id` INT NOT NULL,
    `montant` DECIMAL(10, 2) NOT NULL,
    `date_paiement` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `moyen_paiement` VARCHAR(50),
    `statut` ENUM('Succès', 'Échec', 'En attente') DEFAULT 'Succès',
    FOREIGN KEY (`reservation_id`) REFERENCES `reservations`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET FOREIGN_KEY_CHECKS = 1;
