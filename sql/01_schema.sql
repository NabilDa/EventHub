-- Table SALLE : Représente une salle partenaire [cite: 15]
CREATE TABLE IF NOT EXISTS SALLE 
(
    id_salle INT AUTO_INCREMENT,
    nom VARCHAR(100) NOT NULL,
    capacite_totale INT NOT NULL,
    
    CONSTRAINT pk_salle PRIMARY KEY (id_salle),
    CONSTRAINT uq_nom_salle UNIQUE (nom),
    CONSTRAINT ck_capacite_positive CHECK (capacite_totale > 0)
) ENGINE=InnoDB;

-- Table EVENEMENT : Catalogue des événements [cite: 11]
CREATE TABLE IF NOT EXISTS EVENEMENT 
(
    id_evenement INT AUTO_INCREMENT,
    id_salle INT NOT NULL,
    titre VARCHAR(150) NOT NULL,
    lieu VARCHAR(50) NOT NULL,
    description TEXT,
    categorie VARCHAR(50) NOT NULL, -- Ex: 'Concert', 'Théâtre' [cite: 12]
    date_heure DATETIME NOT NULL,
    prix_base DECIMAL(10, 2) NOT NULL,
    statut ENUM('ACTIF', 'ARCHIVE', 'ANNULE') DEFAULT 'ACTIF', -- [cite: 14]

    CONSTRAINT pk_evenement PRIMARY KEY (id_evenement),
    CONSTRAINT fk_evenement_salle FOREIGN KEY (id_salle) REFERENCES SALLE(id_salle) 
        ON DELETE RESTRICT, 
    CONSTRAINT ck_prix_base_positif CHECK (prix_base >= 0)
) ENGINE=InnoDB;

-- Table PLACE : Modélisation physique des sièges [cite: 16]
CREATE TABLE IF NOT EXISTS PLACE (
    id_place INT AUTO_INCREMENT,
    id_salle INT NOT NULL,
    rangee VARCHAR(5) NOT NULL,
    numero_siege INT NOT NULL,
    type_place ENUM('STANDARD', 'VIP', 'BALCON') NOT NULL DEFAULT 'STANDARD', -- [cite: 17]

    CONSTRAINT pk_place PRIMARY KEY (id_place),
    CONSTRAINT fk_place_salle FOREIGN KEY (id_salle) REFERENCES SALLE(id_salle) ON DELETE CASCADE,
    CONSTRAINT uq_position_place UNIQUE (id_salle, rangee, numero_siege)
) ENGINE=InnoDB;

-- Table CLIENT : Registre des clients [cite: 20]
CREATE TABLE IF NOT EXISTS CLIENT (
    id_client INT AUTO_INCREMENT,
    nom_complet VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL,
    telephone VARCHAR(20),

    CONSTRAINT pk_client PRIMARY KEY (id_client),
    CONSTRAINT uq_email_client UNIQUE (email)
) ENGINE=InnoDB;

-- Table RESERVATION : Historique des commandes
-- MODIFICATION : Ajout de id_evenement pour lien direct
CREATE TABLE IF NOT EXISTS RESERVATION (
    id_reservation INT AUTO_INCREMENT,
    id_client INT NOT NULL,
    id_evenement INT NOT NULL, -- Ajouté pour simplification
    date_reservation DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    statut ENUM('EN_ATTENTE', 'CONFIRMEE', 'ANNULEE') NOT NULL DEFAULT 'EN_ATTENTE', -- [cite: 23]
    montant_total DECIMAL(10, 2) NOT NULL DEFAULT 0.00,

    CONSTRAINT pk_reservation PRIMARY KEY (id_reservation),
    CONSTRAINT fk_res_client FOREIGN KEY (id_client) REFERENCES CLIENT(id_client),
    CONSTRAINT fk_res_evenement FOREIGN KEY (id_evenement) REFERENCES EVENEMENT(id_evenement)
) ENGINE=InnoDB;

-- Table DISPONIBILITE : Gestion du stock et Anti-Surbooking [cite: 32, 33]
CREATE TABLE DISPONIBILITE (
    id_dispo INT AUTO_INCREMENT,
    id_evenement INT NOT NULL,
    id_place INT NOT NULL,
    id_reservation INT NULL, 
    statut ENUM('LIBRE', 'VERROUILLE', 'VENDU') NOT NULL DEFAULT 'LIBRE',
    prix_final DECIMAL(10, 2) NOT NULL, 

    CONSTRAINT pk_disponibilite PRIMARY KEY (id_dispo),
    CONSTRAINT fk_dispo_event FOREIGN KEY (id_evenement) REFERENCES EVENEMENT(id_evenement) ON DELETE CASCADE,
    CONSTRAINT fk_dispo_place FOREIGN KEY (id_place) REFERENCES PLACE(id_place) ON DELETE CASCADE,
    CONSTRAINT fk_dispo_res FOREIGN KEY (id_reservation) REFERENCES RESERVATION(id_reservation) ON DELETE SET NULL,

    -- Contrainte UNIQUE CRITIQUE : Empêche physiquement le surbooking sur la même place
    CONSTRAINT uq_stock_unique UNIQUE (id_evenement, id_place)
) ENGINE=InnoDB;

-- Index pour optimiser la recherche de places libres (Performance)
CREATE INDEX idx_dispo_recherche ON DISPONIBILITE(id_evenement, statut);

-- Table PAIEMENT : Gestion financière [cite: 25]
CREATE TABLE IF NOT EXISTS PAIEMENT (
    id_paiement INT AUTO_INCREMENT,
    id_reservation INT NOT NULL,
    date_paiement DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    montant DECIMAL(10, 2) NOT NULL,
    methode ENUM('CARTE', 'VIREMENT', 'ESPECES') NOT NULL, -- [cite: 26]
    statut ENUM('SUCCES', 'ECHEC', 'EN_TRAITEMENT') NOT NULL DEFAULT 'EN_TRAITEMENT',

    CONSTRAINT pk_paiement PRIMARY KEY (id_paiement),
    CONSTRAINT fk_paiement_res FOREIGN KEY (id_reservation) REFERENCES RESERVATION(id_reservation)
) ENGINE=InnoDB