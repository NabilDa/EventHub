-- Script de test SQL pour EventHub
-- Ce script exécute les scénarios de test via une procédure stockée pour gérer les erreurs attendues.

DELIMITER //

DROP PROCEDURE IF EXISTS `executer_tests` //

CREATE PROCEDURE `executer_tests`()
BEGIN
    -- Variables pour le reporting
    DECLARE v_test1_status VARCHAR(10) DEFAULT 'FAIL';
    DECLARE v_test1_msg VARCHAR(255) DEFAULT '';
    
    DECLARE v_test2_status VARCHAR(10) DEFAULT 'FAIL';
    DECLARE v_test2_msg VARCHAR(255) DEFAULT '';
    
    DECLARE v_test3_status VARCHAR(10) DEFAULT 'FAIL';
    DECLARE v_test3_msg VARCHAR(255) DEFAULT '';

    -- Variables de travail
    DECLARE v_count INT;
    DECLARE v_event_id INT DEFAULT 1; -- Concert Rock
    DECLARE v_client1 INT DEFAULT 1;
    DECLARE v_client2 INT DEFAULT 2;
    DECLARE v_place_id INT;
    
    -- Handler pour capturer les erreurs (nécessaire pour le scénario 2)
    DECLARE v_sql_error INT DEFAULT 0;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_sql_error = 1;

    -- =================================================================================
    -- TEST SCENARIO 1 : Réservation Simple Réussie
    -- "Un client réserve une place spécifique pour un concert."
    -- =================================================================================
    
    SET v_sql_error = 0;
    
    -- Trouver une place libre (ex: Salle 1, A, 5)
    SELECT id INTO v_place_id FROM places WHERE salle_id = 1 AND rangee = 'A' AND numero = 5 LIMIT 1;
    
    CALL reserver_place_atomique(v_client1, v_event_id, v_place_id, 'Carte Bancaire');
    
    IF v_sql_error = 0 THEN
        -- Vérifier que la réservation existe
        SELECT COUNT(*) INTO v_count 
        FROM reservations 
        WHERE evenement_id = v_event_id AND place_id = v_place_id AND statut = 'Confirmée';
        
        IF v_count = 1 THEN
            SET v_test1_status = 'PASS';
            SET v_test1_msg = 'Réservation effectuée et confirmée.';
        ELSE
            SET v_test1_msg = 'Pas d''erreur SQL, mais réservation introuvable.';
        END IF;
    ELSE
        SET v_test1_msg = 'Erreur SQL inattendue lors de la réservation.';
    END IF;

    -- =================================================================================
    -- TEST SCENARIO 2 : Tentative de Double Réservation
    -- "Deux clients tentent de réserver la même place... un seul doit réussir"
    -- Ici, la place v_place_id est DÉJÀ réservée par le Test 1.
    -- On essaie de la réserver à nouveau avec un autre client. Cela DOIT échouer.
    -- =================================================================================

    SET v_sql_error = 0; -- Reset error flag
    
    CALL reserver_place_atomique(v_client2, v_event_id, v_place_id, 'PayPal');
    
    IF v_sql_error = 1 THEN
        -- C'est ce qu'on veut ! Une erreur a été levée.
        SET v_test2_status = 'PASS';
        SET v_test2_msg = 'La double réservation a été bloquée correctement (Erreur SQL capturée).';
    ELSE
        -- Si pas d'erreur, c'est un échec du test (la contrainte n'a pas marché)
        SET v_test2_status = 'FAIL';
        SET v_test2_msg = 'ALERTE: La deuxième réservation a été acceptée (Overbooking!).';
    END IF;

    -- =================================================================================
    -- TEST SCENARIO 3 : Réservation Groupée
    -- "Une famille de 4 personnes veut réserver 4 places côte à côte."
    -- =================================================================================
    
    SET v_sql_error = 0;
    SET v_count = 0;
    
    -- Utilisons un autre événement ou le même s'il reste de la place.
    -- Event 2 (Théâtre) est vide au départ.
    
    CALL reserver_groupe_atomique(3, 2, 4, 'Virement'); -- Client 3 (Famille), Event 2
    
    IF v_sql_error = 0 THEN
        -- Vérifier qu'on a bien 4 réservations pour ce client sur cet event
        SELECT COUNT(*) INTO v_count 
        FROM reservations 
        WHERE client_id = 3 AND evenement_id = 2 AND statut = 'Confirmée';
        
        IF v_count = 4 THEN
            SET v_test3_status = 'PASS';
            SET v_test3_msg = CONCAT('Groupe de 4 places réservé avec succès.');
        ELSE
            SET v_test3_msg = CONCAT('Attendu 4 réservations, trouvé ', v_count);
        END IF;
    ELSE
        SET v_test3_msg = 'Erreur SQL lors de la réservation de groupe.';
    END IF;

    -- =================================================================================
    -- RÉSULTATS
    -- =================================================================================
    SELECT 'Scenario 1 (Simple)' AS Test, v_test1_status AS Status, v_test1_msg AS Message
    UNION ALL
    SELECT 'Scenario 2 (Double Booking)', v_test2_status, v_test2_msg
    UNION ALL
    SELECT 'Scenario 3 (Groupe)', v_test3_status, v_test3_msg;

END //

DELIMITER ;

-- Exécuter les tests
CALL executer_tests();
