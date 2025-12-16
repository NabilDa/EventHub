DELIMITER //

-- Procédure pour créer une salle et générer automatiquement ses places
-- BF2.4 : Automatiser la création des places lors de l'ajout d'une nouvelle salle
CREATE PROCEDURE `creer_salle_automatique`(
    IN p_nom VARCHAR(100),
    IN p_nb_rangees INT,
    IN p_places_par_rangee INT
)
BEGIN
    DECLARE v_salle_id INT;
    DECLARE v_r INT DEFAULT 1;
    DECLARE v_p INT DEFAULT 1;
    DECLARE v_type_std INT;

    -- Récupérer l'ID du type standard (supposons ID 1 ou recherche)
    SELECT id INTO v_type_std FROM `types_place` WHERE `nom` = 'Standard' LIMIT 1;
    IF v_type_std IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Type de place Standard introuvable';
    END IF;

    START TRANSACTION;

    -- Créer la salle
    INSERT INTO `salles` (`nom`, `capacite`) 
    VALUES (p_nom, p_nb_rangees * p_places_par_rangee);
    
    SET v_salle_id = LAST_INSERT_ID();

    -- Générer les places
    WHILE v_r <= p_nb_rangees DO
        SET v_p = 1;
        WHILE v_p <= p_places_par_rangee DO
            -- Format rangée: 'A', 'B', etc. si < 26, sinon 'Row-X'.
            -- Simplification: Utilisons juste le numéro de rangée converti en CHAR ou concat.
            -- Pour faire joli: CHAR(64 + v_r) convertit 1->A, 2->B...
            INSERT INTO `places` (`salle_id`, `rangee`, `numero`, `type_place_id`)
            VALUES (v_salle_id, CHAR(64 + v_r), v_p, v_type_std);
            
            SET v_p = v_p + 1;
        END WHILE;
        SET v_r = v_r + 1;
    END WHILE;

    COMMIT;
END;
//

-- Procédure de réservation atomique (Place unique)
-- Scénario 1 & 2
CREATE PROCEDURE `reserver_place_atomique`(
    IN p_client_id INT,
    IN p_evenement_id INT,
    IN p_place_id INT,
    IN p_moyen_paiement VARCHAR(50)
)
BEGIN
    DECLARE v_prix_base DECIMAL(10,2);
    DECLARE v_coeff DECIMAL(5,2);
    DECLARE v_montant DECIMAL(10,2);
    DECLARE v_reservation_id INT;
    DECLARE v_count INT;

    -- Gestion des erreurs
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- 1. Vérifier si la place est déjà prise (Lock For Update pour éviter race condition avant l'insert)
    -- L'index unique uk_reservation_active protège au final, mais le check ici permet un retour plus propre.
    SELECT COUNT(*) INTO v_count 
    FROM `reservations` 
    WHERE `evenement_id` = p_evenement_id 
      AND `place_id` = p_place_id 
      AND `statut` = 'Confirmée'
    FOR UPDATE;

    IF v_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erreur: Cette place est déjà réservée.';
    END IF;

    -- 2. Calcul du prix
    SELECT e.prix_base, tp.coefficient_prix 
    INTO v_prix_base, v_coeff
    FROM `evenements` e
    JOIN `places` p ON p.id = p_place_id
    JOIN `types_place` tp ON tp.id = p.type_place_id
    WHERE e.id = p_evenement_id;

    SET v_montant = v_prix_base * v_coeff;

    -- 3. Créer la réservation
    INSERT INTO `reservations` (`client_id`, `evenement_id`, `place_id`, `statut`)
    VALUES (p_client_id, p_evenement_id, p_place_id, 'Confirmée');
    
    SET v_reservation_id = LAST_INSERT_ID();

    -- 4. Enregistrer le paiement
    INSERT INTO `paiements` (`reservation_id`, `montant`, `moyen_paiement`, `statut`)
    VALUES (v_reservation_id, v_montant, p_moyen_paiement, 'Succès');

    COMMIT;
END;
//

-- Procédure de réservation de groupe (Places contiguës)
-- Scénario 3
CREATE PROCEDURE `reserver_groupe_atomique`(
    IN p_client_id INT,
    IN p_evenement_id INT,
    IN p_nb_places INT,
    IN p_moyen_paiement VARCHAR(50)
)
BEGIN
    DECLARE v_salle_id INT;
    DECLARE v_prix_base DECIMAL(10,2);
    DECLARE done INT DEFAULT 0;
    
    -- Variables pour la recherche
    DECLARE v_rangee VARCHAR(10);
    DECLARE v_start_num INT;
    DECLARE v_found BOOLEAN DEFAULT FALSE;
    
    -- Variables pour la boucle d'insertion
    DECLARE i INT;
    DECLARE v_place_id INT;
    DECLARE v_coeff DECIMAL(5,2);
    DECLARE v_montant DECIMAL(10,2);
    DECLARE v_reservation_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Récupérer info événement
    SELECT salle_id, prix_base INTO v_salle_id, v_prix_base
    FROM evenements WHERE id = p_evenement_id;

    -- Algorithme de recherche de places contiguës
    -- On cherche une rangée et un numéro de départ où les X places suivantes sont libres.
    -- Ceci est une implémentation simplifiée.
    
    SELECT p1.rangee, p1.numero
    INTO v_rangee, v_start_num
    FROM places p1
    WHERE p1.salle_id = v_salle_id
    -- Vérifier que la séquence p1, p1+1 ... p1+(nb-1) existe et n'est pas réservée
    AND (
        SELECT COUNT(*)
        FROM places p2
        LEFT JOIN reservations r ON r.place_id = p2.id AND r.evenement_id = p_evenement_id AND r.statut = 'Confirmée'
        WHERE p2.salle_id = v_salle_id
          AND p2.rangee = p1.rangee
          AND p2.numero BETWEEN p1.numero AND (p1.numero + p_nb_places - 1)
          AND r.id IS NULL -- Pas de réservation active
    ) = p_nb_places
    LIMIT 1
    FOR UPDATE; -- Verrouiller les lignes lues serait mieux, mais complexe en une seule requête.
                -- Ici on fait confiance à la transaction et à l'insert qui échouera si conflit.

    IF v_rangee IS NULL THEN
         SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pas de places contiguës disponibles.';
    END IF;

    -- Insérer les réservations et paiements
    SET i = 0;
    WHILE i < p_nb_places DO
        -- Retrouver l'ID de la place et son coefficient
        SELECT p.id, tp.coefficient_prix INTO v_place_id, v_coeff
        FROM places p
        JOIN types_place tp ON p.type_place_id = tp.id
        WHERE p.salle_id = v_salle_id AND p.rangee = v_rangee AND p.numero = (v_start_num + i);

        SET v_montant = v_prix_base * v_coeff;

        INSERT INTO `reservations` (`client_id`, `evenement_id`, `place_id`, `statut`)
        VALUES (p_client_id, p_evenement_id, v_place_id, 'Confirmée');
        
        SET v_reservation_id = LAST_INSERT_ID();

        INSERT INTO `paiements` (`reservation_id`, `montant`, `moyen_paiement`, `statut`)
        VALUES (v_reservation_id, v_montant, p_moyen_paiement, 'Succès');

        SET i = i + 1;
    END WHILE;

    COMMIT;
END;
//

DELIMITER ;
