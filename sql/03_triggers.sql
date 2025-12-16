DELIMITER //

-- Trigger pour mettre à jour le compteur de places vendues lors d'une nouvelle réservation
CREATE TRIGGER `trg_after_reservation_insert`
AFTER INSERT ON `reservations`
FOR EACH ROW
BEGIN
    IF NEW.statut = 'Confirmée' THEN
        UPDATE `evenements`
        SET `places_vendues` = `places_vendues` + 1
        WHERE `id` = NEW.evenement_id;
    END IF;
END;
//

-- Trigger pour mettre à jour le compteur lors d'une modification (ex: Annulation)
CREATE TRIGGER `trg_after_reservation_update`
AFTER UPDATE ON `reservations`
FOR EACH ROW
BEGIN
    -- Si passe de non-confirmée (improbable ici car insert default confirmée) à confirmée
    IF NEW.statut = 'Confirmée' AND OLD.statut != 'Confirmée' THEN
        UPDATE `evenements`
        SET `places_vendues` = `places_vendues` + 1
        WHERE `id` = NEW.evenement_id;
    -- Si passe de confirmée à annulée
    ELSEIF NEW.statut != 'Confirmée' AND OLD.statut = 'Confirmée' THEN
        UPDATE `evenements`
        SET `places_vendues` = `places_vendues` - 1
        WHERE `id` = NEW.evenement_id;
    END IF;
END;
//

DELIMITER ;
