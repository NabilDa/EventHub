-- 04_seed.sql

-- 1. Catégories
INSERT INTO `categories_evenement` (`nom`) VALUES 
('Concert'), ('Théâtre'), ('Conférence'), ('Spectacle');

-- 2. Types de Place
INSERT INTO `types_place` (`nom`, `coefficient_prix`) VALUES 
('Standard', 1.00), 
('VIP', 1.50), 
('Balcon', 0.80);

-- 3. Clients
INSERT INTO `clients` (`nom`, `email`, `telephone`) VALUES 
('Jean Dupont', 'jean.dupont@email.com', '0601020304'),
('Marie Martin', 'marie.martin@email.com', '0605060708'),
('Famille Durand', 'famille.durand@email.com', '0610111213'),
('Concurrent A', 'a@test.com', '0000000001'),
('Concurrent B', 'b@test.com', '0000000002');

-- 4. Création d'une salle via procédure (Salle 1: 5 rangées de 10 places = 50 places)
CALL creer_salle_automatique('Grande Salle', 5, 10);

-- Mise à jour de la première rangée en VIP
UPDATE `places` 
SET `type_place_id` = (SELECT id FROM `types_place` WHERE nom = 'VIP')
WHERE `salle_id` = 1 AND `rangee` = 'A';

-- 5. Création d'un événement
INSERT INTO `evenements` (`titre`, `description`, `categorie_id`, `salle_id`, `date_debut`, `date_fin`, `prix_base`, `statut`) 
VALUES 
('Concert Rock', 'Le plus grand concert de l''année', 1, 1, '2023-12-01 20:00:00', '2023-12-01 23:00:00', 50.00, 'Actif'),
('Pièce de Théâtre', 'Une tragédie classique', 2, 1, '2023-12-05 19:00:00', '2023-12-05 21:00:00', 30.00, 'Actif');
