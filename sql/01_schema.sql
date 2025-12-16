/*-------------------------------------------------*/
/*              CREATION DES TABLES                */
/*-------------------------------------------------*/

-- Table SALLE : Représente une salle de cinéma
CREATE TABLE IF NOT EXISTS SALLE 
(
    id_salle INT AUTO_INCREMENT,
    nom VARCHAR(100) NOT NULL,
    capacite_totale INT NOT NULL,
    
    -- Contraintes
    CONSTRAINT pk_salle PRIMARY KEY (id_salle),
    CONSTRAINT uq_nom_salle UNIQUE (nom), -- Pour éviter d'avoir deux salles avec le même nom
    CONSTRAINT ck_capacite_positive CHECK (capacite_totale > 0) -- Sécurité : une salle ne peut pas avoir 0 ou -5 places
) ENGINE=InnoDB;

-- Table EVENEMENT : Représente un événement
CREATE TABLE IF NOT EXISTS EVENEMENT 
(
    id_evenement INT AUTO_INCREMENT,
    id_salle INT NOT NULL,
    titre VARCHAR(150) NOT NULL,
    description TEXT,
    categorie VARCHAR(50) NOT NULL, -- Ex: 'Concert', 'Théâtre'
    date_heure DATETIME NOT NULL,
    prix_base DECIMAL(10, 2) NOT NULL,
    statut ENUM('ACTIF', 'ARCHIVE', 'ANNULE') DEFAULT 'ACTIF',

    CONSTRAINT pk_evenement PRIMARY KEY (id_evenement),
    CONSTRAINT fk_evenement_salle FOREIGN KEY (id_salle) REFERENCES SALLE(id_salle) 
        ON DELETE RESTRICT, -- Empêche de supprimer une salle si des événements y sont prévus
    CONSTRAINT ck_prix_base_positif CHECK (prix_base >= 0)
) ENGINE=InnoDB;

-- Table PLACE : Représente une place dans une salle
CREATE TABLE IF NOT EXISTS PLACE (
    id_place INT AUTO_INCREMENT,
    id_salle INT NOT NULL,
    rangee VARCHAR(5) NOT NULL,        -- Ex: 'A', 'B', 'AA'
    numero_siege INT NOT NULL,         -- Ex: 1, 2, 12
    type_place ENUM('STANDARD', 'VIP', 'BALCON') NOT NULL DEFAULT 'STANDARD',

    CONSTRAINT pk_place PRIMARY KEY (id_place),
    CONSTRAINT fk_place_salle FOREIGN KEY (id_salle) REFERENCES SALLE(id_salle) ON DELETE CASCADE,
    
    -- Empêcher les doublons physiques : 
    -- On ne peut pas avoir deux fois le siège A-12 dans la même salle
    CONSTRAINT uq_position_place UNIQUE (id_salle, rangee, numero_siege)
) ENGINE=InnoDB;

-- Table CLIENT : Représente un client
CREATE TABLE IF NOT EXISTS CLIENT (
    id_client INT AUTO_INCREMENT,
    nom_complet VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL,
    telephone VARCHAR(20),

    CONSTRAINT pk_client PRIMARY KEY (id_client),
    CONSTRAINT uq_email_client UNIQUE (email) -- Un email = un compte unique
) ENGINE=InnoDB;

-- Table RESERVATION : Représente une réservation effectuée par un client
CREATE TABLE IF NOT EXISTS RESERVATION (
    id_reservation INT AUTO_INCREMENT,
    id_client INT NOT NULL,
    date_reservation DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    statut ENUM('EN_ATTENTE', 'CONFIRMEE', 'ANNULEE') NOT NULL DEFAULT 'EN_ATTENTE',
    montant_total DECIMAL(10, 2) NOT NULL DEFAULT 0.00,

    CONSTRAINT pk_reservation PRIMARY KEY (id_reservation),
    CONSTRAINT fk_res_client FOREIGN KEY (id_client) REFERENCES CLIENT(id_client)
) ENGINE=InnoDB;

-- Table DISPONIBILITE : Représente la disponibilité des places pour un événement spécifique
CREATE TABLE DISPONIBILITE (
    id_dispo INT AUTO_INCREMENT,
    id_evenement INT NOT NULL,
    id_place INT NOT NULL,
    id_reservation INT NULL, -- NULL = Libre
    statut ENUM('LIBRE', 'VERROUILLE', 'VENDU') NOT NULL DEFAULT 'LIBRE',
    prix_final DECIMAL(10, 2) NOT NULL, -- Prix fixé pour cet événement spécifique

    CONSTRAINT pk_disponibilite PRIMARY KEY (id_dispo),
    
    CONSTRAINT fk_dispo_event FOREIGN KEY (id_evenement) REFERENCES EVENEMENT(id_evenement) ON DELETE CASCADE,
    CONSTRAINT fk_dispo_place FOREIGN KEY (id_place) REFERENCES PLACE(id_place) ON DELETE CASCADE,
    CONSTRAINT fk_dispo_res FOREIGN KEY (id_reservation) REFERENCES RESERVATION(id_reservation) ON DELETE SET NULL,

    -- Contrainte Métier CRITIQUE (BF3.2 & Anti-Surbooking)
    -- Une place physique ne peut apparaître qu'une seule fois dans le stock d'un événement
    CONSTRAINT uq_stock_unique UNIQUE (id_evenement, id_place)
) ENGINE=InnoDB;

-- Table PAIEMENT : Représente un paiement effectué pour une réservation
CREATE TABLE IF NOT EXISTS PAIEMENT (
    id_paiement INT AUTO_INCREMENT,
    id_reservation INT NOT NULL,
    date_paiement DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    montant DECIMAL(10, 2) NOT NULL,
    methode ENUM('CARTE', 'VIREMENT', 'ESPECES') NOT NULL,
    statut ENUM('SUCCES', 'ECHEC', 'EN_TRAITEMENT') NOT NULL DEFAULT 'EN_TRAITEMENT',

    CONSTRAINT pk_paiement PRIMARY KEY (id_paiement),
    CONSTRAINT fk_paiement_res FOREIGN KEY (id_reservation) REFERENCES RESERVATION(id_reservation)
) ENGINE=InnoDB;