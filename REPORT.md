# Rapport de Conception - EventHub

Ce document détaille les choix techniques et fonctionnels effectués lors de la conception et de l'implémentation de la base de données EventHub.

## 1. Choix d'Infrastructure

*   **SGBD**: MariaDB 11.1.2 a été choisi conformément à la demande. Cette version récente permet l'utilisation de fonctionnalités avancées comme les colonnes générées persistantes.
*   **Conteneurisation**: Utilisation de `docker-compose` pour garantir un environnement reproductible et isoler la base de données.
*   **Initialisation**: Montage du dossier `./sql` dans `/docker-entrypoint-initdb.d` pour assurer l'exécution automatique des scripts SQL au premier démarrage du conteneur, garantissant une base prête à l'emploi.

## 2. Modélisation de la Base de Données (Schema)

### 2.1 Langue et Naming Convention
*   **Langue**: Français, conformément à l'exigence explicite ("Use French").
    *   Tables : `evenements`, `places`, `salles`, etc.
    *   Colonnes : `titre`, `prix_base`, `date_debut`, etc.
*   **Conventions**: Snake_case standard pour les bases de données SQL.

### 2.2 Modèle de Tarification
Pour répondre aux besoins de tarification flexible (BF1.1 vs BF2.3) :
*   **Prix de base** sur l'`evenement`.
*   **Coefficient** sur le `type_place` (ex: VIP = 1.5, Standard = 1.0).
*   **Calcul**: Le prix final est calculé dynamiquement (`prix_base * coefficient`) lors de la réservation. Cela évite de stocker un prix fixe par place/événement tout en permettant une flexibilité totale.

### 2.3 Gestion de l'Historique (Archivage)
*   Plutôt que de déplacer les données dans une table séparée (complexe à maintenir), le choix s'est porté sur une colonne `statut` ('Actif', 'Archivé') dans la table `evenements`. Cela simplifie les requêtes d'historique tout en permettant de filtrer les événements courants.

## 3. Gestion de la Surréservation (Constraint Critical)

C'est le point le plus critique du système ("Il est strictement interdit de vendre deux fois la même place").

**Solution retenue : Index Unique Conditionnel (Virtual Column)**

*   **Problème**: Une contrainte `UNIQUE(evenement_id, place_id)` classique empêcherait de re-réserver une place si une précédente réservation avait été annulée (car la ligne existerait toujours).
*   **Solution**: Création d'une colonne générée persistante `verrou_reservation`.
    *   Formule : `IF(statut = 'Confirmée', CONCAT(evenement_id, '-', place_id), NULL)`
    *   Si la réservation est 'Annulée', la colonne vaut `NULL`.
    *   Si la réservation est 'Confirmée', elle contient une clé unique.
*   **Avantage**: Les bases de données SQL autorisent plusieurs `NULL` dans un index UNIQUE. Ainsi, on peut avoir une infinité de réservations annulées pour une place, mais **une seule** confirmée.
*   **Sécurité**: Cette contrainte est appliquée au niveau du moteur de stockage (InnoDB). Même si deux transactions concurrentes passent les vérifications logicielles, la seconde échouera fatalement au moment de l'écriture (Commit).

## 4. Logique Métier et Transactions

### 4.1 Transactions Atomiques
L'exigence de lier réservation et paiement a été traitée via des **Procédures Stockées** (`reserver_place_atomique`).
*   Utilisation de `START TRANSACTION`, `COMMIT` et `ROLLBACK`.
*   Gestion des erreurs via `DECLARE EXIT HANDLER FOR SQLEXCEPTION`.
*   Cela garantit que l'on ne peut jamais avoir une réservation "Confirmée" sans paiement associé ("Intégrité Financière").

### 4.2 Automatisation
Pour simplifier la gestion (BF2.4), la procédure `creer_salle_automatique` génère physiquement les lignes dans la table `places` (A-1, A-2, B-1...) selon la capacité définie. Cela évite une saisie manuelle fastidieuse.

### 4.3 Statistiques Temps Réel
Utilisation de **Triggers** (`AFTER INSERT`, `AFTER UPDATE`) sur la table `reservations` pour maintenir un compteur dénormalisé `places_vendues` dans la table `evenements`.
*   **Pourquoi ?**: Évite de faire un `COUNT(*)` coûteux sur la table des réservations à chaque fois qu'on affiche la liste des événements.

## 5. Stratégie de Test

*   **Initialement**: Des tests Python ont été envisagés.
*   **Finalement**: Bascule vers des tests **100% SQL** (`tests/test_scenarios.sql`).
*   **Pourquoi ?**: Plus portable, ne nécessite pas d'installer Python/Drivers sur l'environnement de base de données, et permet de tester directement la logique stockée (Procédures/Triggers) dans son environnement natif.
*   **Méthodologie**: Création d'une procédure `executer_tests` qui simule les cas d'usage et capture les exceptions SQL attendues (ex: échec d'une double réservation) pour valider le succès du test.
