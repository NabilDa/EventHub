# 🎫 EventHub

A **MariaDB-based event booking system** with atomic reservations, overbooking prevention, and dynamic pricing — fully containerized with Docker.

## Features

- **Atomic Reservations** — Single and group bookings wrapped in transactions, ensuring reservation + payment integrity.
- **Overbooking Prevention** — A persistent virtual column (`verrou_reservation`) with a unique index guarantees no seat is double-booked, even under concurrent access.
- **Dynamic Pricing** — Base price per event × seat-type coefficient (e.g. VIP ×1.5, Balcon ×0.8).
- **Automatic Venue Setup** — Stored procedure generates all seats (rows A–Z, numbered) when creating a venue.
- **Real-Time Stats** — Triggers on `reservations` maintain a denormalized `places_vendues` counter on each event.
- **Event Archiving** — Status-based archiving (`Actif` / `Annulé` / `Archivé`) instead of table duplication.
- **Pure SQL Tests** — Test scenarios run entirely in SQL via a `executer_tests` stored procedure.

## Tech Stack

| Component | Version |
|-----------|---------|
| MariaDB   | 11.1.2  |
| Docker Compose | v2+ |

## Quick Start

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/install/)

### Launch

```bash
docker-compose up -d
```

This starts a MariaDB container and automatically runs the SQL scripts in `sql/` to create the schema, procedures, triggers, and seed data.

### Connect

```bash
docker exec -it eventhub mariadb -u eventhub_user -puserpassword eventhub
```

### Reset (tear down & rebuild)

```bash
docker-compose down -v
docker-compose up -d
```

## Project Structure

```
EventHub/
├── docker-compose.yml        # MariaDB 11.1.2 service definition
├── sql/
│   ├── 01_schema.sql         # Tables: salles, places, evenements, clients, reservations, paiements
│   ├── 02_procedures.sql     # Stored procedures (reserver_place_atomique, reserver_groupe_atomique, creer_salle_automatique)
│   ├── 03_triggers.sql       # Triggers for places_vendues counter
│   └── 04_seed.sql           # Sample data (categories, seat types, clients, venue, events)
├── test_scenarios.sql         # SQL test suite (executer_tests procedure)
└── REPORT.md                  # Detailed design report (in French)
```

## Database Schema

```
salles ──< places >── types_place
              │
evenements ──< reservations >── clients
                    │
                paiements
```

**Key tables:**

| Table | Purpose |
|-------|---------|
| `salles` | Venues with auto-generated capacity |
| `types_place` | Seat categories with price coefficients |
| `places` | Individual seats (row + number) |
| `evenements` | Events with base price and live sold-count |
| `clients` | Customer records |
| `reservations` | Bookings with overbooking lock column |
| `paiements` | Payment records tied to reservations |

## Running Tests

Connect to the database and execute the test script:

```bash
docker exec -i eventhub mariadb -u eventhub_user -puserpassword eventhub < test_scenarios.sql
```

The `executer_tests` procedure runs three scenarios:

| # | Scenario | Expected |
|---|----------|----------|
| 1 | Simple reservation | PASS — booking confirmed |
| 2 | Double booking same seat | PASS — blocked by unique constraint |
| 3 | Group reservation (4 seats) | PASS — contiguous seats booked |

## License

This project is provided as-is for educational purposes.
