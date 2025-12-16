/*-----------------------------------------------------------------------------------*/
/* FICHIER : 03_procedures.sql                                                       */
/* PROJET  : EventHub                                                                */
/* DESCRIPTION : Contient toute la logique métier (Création, Réservation, Paiement)  */
/*-----------------------------------------------------------------------------------*/

DELIMITER $$

/* -----------------------------------------------------------------------------------
   PROCEDURE 1 : AjouterSalleAuto (BF2.4)
   Description : Automatise la création d'une salle et génère physiquement les places.
   Usage : CALL AjouterSalleAuto('Grand Théâtre', 50, 10);
----------------------------------------------------------------------------------- */
DROP PROCEDURE IF EXISTS AjouterSalleAuto$$

CREATE PROCEDURE AjouterSalleAuto(
    IN p_nom_salle VARCHAR(100),
    IN p_capacite INT,
    IN p_sieges_par_rangee INT
)
BEGIN
    DECLARE v_id_salle INT;
    DECLARE v_i INT DEFAULT 0;
    DECLARE v_rangee CHAR(2);
    DECLARE v_num_siege INT;
    DECLARE v_type VARCHAR(20);

    -- 1. Insérer la salle
    INSERT INTO SALLE (nom, capacite_totale) VALUES (p_nom_salle, p_capacite);
    SET v_id_salle = LAST_INSERT_ID();

    -- 2. Boucler pour créer les places
    WHILE v_i < p_capacite DO
        -- Génération lettre rangée (A, B, C...)
        SET v_rangee = CHAR(65 + FLOOR(v_i / p_sieges_par_rangee));
        
        -- Génération numéro siège (1, 2, 3...)
        SET v_num_siege = (v_i % p_sieges_par_rangee) + 1;

        -- Définition type place (A et B sont VIP, le reste STANDARD)
        IF v_rangee IN ('A', 'B') THEN
            SET v_type = 'VIP';
        ELSE
            SET v_type = 'STANDARD';
        END IF;

        INSERT INTO PLACE (id_salle, rangee, numero_siege, type_place)
        VALUES (v_id_salle, v_rangee, v_num_siege, v_type);

        SET v_i = v_i + 1;
    END WHILE;
END$$

/* -----------------------------------------------------------------------------------
   PROCEDURE 2 : GenererDisponibilites (BF1.3)
   Description : Génère le stock de billets (table DISPONIBILITE) pour un événement.
   Usage : CALL GenererDisponibilites(1);
----------------------------------------------------------------------------------- */
DROP PROCEDURE IF EXISTS GenererDisponibilites$$

CREATE PROCEDURE GenererDisponibilites(IN p_id_evenement INT)
BEGIN
    DECLARE v_id_salle INT;
    DECLARE v_prix_base DECIMAL(10, 2);

    -- Récupérer infos événement
    SELECT id_salle, prix_base INTO v_id_salle, v_prix_base
    FROM EVENEMENT WHERE id_evenement = p_id_evenement;

    -- Insertion en masse
    INSERT INTO DISPONIBILITE (id_evenement, id_place, statut, prix_final)
    SELECT 
        p_id_evenement,
        id_place,
        'LIBRE',
        CASE 
            WHEN type_place = 'VIP' THEN v_prix_base * 1.50 
            WHEN type_place = 'BALCON' THEN v_prix_base * 1.20
            ELSE v_prix_base 
        END
    FROM PLACE 
    WHERE id_salle = v_id_salle;
END$$

/* -----------------------------------------------------------------------------------
   PROCEDURE 3 : EffectuerReservationSimple (BF3.2 & Anti-Surbooking)
   Description : Transaction atomique pour réserver une place. Verrouille la ligne.
   Usage : CALL EffectuerReservationSimple(id_client, id_event, id_place);
----------------------------------------------------------------------------------- */
DROP PROCEDURE IF EXISTS EffectuerReservationSimple$$

CREATE PROCEDURE EffectuerReservationSimple(
    IN p_id_client INT,
    IN p_id_evenement INT,
    IN p_id_place INT
)
BEGIN
    DECLARE v_id_dispo INT;
    DECLARE v_prix_final DECIMAL(10,2);
    DECLARE v_id_reservation INT;
    
    -- Handler en cas d'erreur (Rollback automatique)
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erreur: Transaction annulée.';
    END;

    START TRANSACTION;

    -- VERROUILLAGE (FOR UPDATE) : Empêche la double réservation
    SELECT id_dispo, prix_final INTO v_id_dispo, v_prix_final
    FROM DISPONIBILITE
    WHERE id_evenement = p_id_evenement 
      AND id_place = p_id_place 
      AND statut = 'LIBRE'
    FOR UPDATE; 

    IF v_id_dispo IS NULL THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ECHEC: Place déjà prise ou inexistante.';
    ELSE
        -- Créer la réservation
        INSERT INTO RESERVATION (id_client, id_evenement, statut, montant_total)
        VALUES (p_id_client, p_id_evenement, 'EN_ATTENTE', v_prix_final);
        
        SET v_id_reservation = LAST_INSERT_ID();

        -- Verrouiller la disponibilité
        UPDATE DISPONIBILITE 
        SET statut = 'VERROUILLE', 
            id_reservation = v_id_reservation
        WHERE id_dispo = v_id_dispo;

        COMMIT;
    END IF;
END$$

/* -----------------------------------------------------------------------------------
   PROCEDURE 4 : ConfirmerPaiement (BF4.1)
   Description : Valide le paiement, confirme la réservation et vend la place.
   Usage : CALL ConfirmerPaiement(id_reservation, montant, 'CARTE');
----------------------------------------------------------------------------------- */
DROP PROCEDURE IF EXISTS ConfirmerPaiement$$

CREATE PROCEDURE ConfirmerPaiement(
    IN p_id_reservation INT,
    IN p_montant DECIMAL(10, 2),
    IN p_methode VARCHAR(20)
)
BEGIN
    DECLARE v_montant_attendu DECIMAL(10, 2);
    DECLARE v_statut_res VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erreur: Paiement annulé.';
    END;

    START TRANSACTION;

    -- Vérification
    SELECT montant_total, statut INTO v_montant_attendu, v_statut_res
    FROM RESERVATION 
    WHERE id_reservation = p_id_reservation
    FOR UPDATE;

    IF v_montant_attendu IS NULL THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ECHEC: Réservation introuvable.';
    ELSEIF v_statut_res != 'EN_ATTENTE' THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ECHEC: Réservation déjà traitée.';
    ELSEIF p_montant != v_montant_attendu THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ECHEC: Montant incorrect.';
    ELSE
        -- Enregistrer paiement
        INSERT INTO PAIEMENT (id_reservation, montant, methode, statut)
        VALUES (p_id_reservation, p_montant, p_methode, 'SUCCES');

        -- Mettre à jour réservation
        UPDATE RESERVATION SET statut = 'CONFIRMEE' WHERE id_reservation = p_id_reservation;

        -- Mettre à jour stock (VENDU)
        UPDATE DISPONIBILITE SET statut = 'VENDU' WHERE id_reservation = p_id_reservation;

        COMMIT;
    END IF;
END$$

DELIMITER ;