<!-- ════════════════════════════════════════════════════════════════
     BLOC CONVENTIONS — à placer EN TÊTE du CLAUDE.md généré par /init.
     Le descriptif d'architecture /init reste tel quel en dessous.
     ════════════════════════════════════════════════════════════════ -->

# Conventions projet — cobroc

> Nom officiel du projet : **cobroc** (orthographe unique, ne pas écrire
> « cobrac » ni « Cobrac » dans le code, les commentaires ou les messages).

## Convention OBLIGATOIRE — en-tête de fichier

**Tout fichier créé ou modifié DOIT commencer par cet en-tête**, mis à jour à
chaque intervention :

```dart
// lib/[CHEMIN]/fichier.dart
// Modified: YYMMDDHHMMM
// [TITRE]
// CHANGEMENTS: (1) [Quoi] ligne X, (2) [Quoi] ligne Y, (3) [Quoi] ligne Z
```

Règles : chemin réel du fichier ; horodatage à la minute ; titre court ; liste
numérotée des changements de l'intervention en cours, avec les lignes concernées.
Ne JAMAIS omettre cet en-tête, y compris sur les fichiers existants modifiés.

## Gestion d'état (état réel du code)

- L'app utilise actuellement **`setState`** + **`SharedPreferences`**
  (`StorageService`) pour la persistance. PAS de Riverpod en place.
- **Ne pas migrer vers Riverpod** ni introduire une autre lib d'état de ta propre
  initiative. Si une migration Riverpod est souhaitée, elle sera demandée
  EXPLICITEMENT et traitée comme un chantier à part, fichier par fichier.

## Conventions de code

- **Imports absolus** (package imports), pas de chemins relatifs.
- **Architecture propre** privilégiée sur la rustine rapide ; respecter la
  séparation existante services / widgets / models / screens.
- Précision et **vérification pas à pas**, pas d'automatisation hâtive.
- Commentaires en français ; **termes techniques IA/ML en anglais** non traduits
  (tool-calling, prompt, token, embedding, inference, structured output, RAG…).
- Style Dart : passer `dart format` ; viser `flutter analyze` **sans warning**
  avant de présenter un diff.

## Contraintes — IMPORTANT

- **Légal / Brocabrac (BLOQUANT publication).** cobroc scrape brocabrac.fr
  (`NetworkHelper`, extraction ld+json). La publication est SUSPENDUE tant que les
  questions de droits sur les données ne sont pas tranchées (droit *sui generis*
  sur les bases de données, CGU du site). En conséquence :
    - Ne PAS rendre le scraping plus agressif (fréquence, parallélisme au-delà de
      l'existant, contournement de protections, ignorance du robots.txt).
    - Ne PAS pousser vers une mise en production / publication.
    - SIGNALER tout changement qui aggraverait l'exposition juridique.
- **Secrets** : aucune clé/identifiant en clair dans le dépôt.
- **Données statiques compilées** (`listHistoric`, `listCommunes`,
  `listVillesFrance`) : grosses listes intégrées au binaire — éviter de les
  reformater ou réordonner massivement sans raison (diffs énormes, revue impossible).

## Périmètre des interventions

- Faire : diffs ciblés, raisonnement explicite, respect de l'en-tête, vérif
  `flutter analyze`.
- Ne pas faire : refactor massif non demandé, changement de lib d'état,
  modification du comportement de scraping Brocabrac sans validation, publication.

## Monorepo — `server/` (tooling données Python)

Le dossier **`server/`** contient l'outillage data (ex-repo `cobroc-server`,
intégré par `git subtree`) : serveur FastAPI de saisie des visites, base SQLite
`server/db/historibroc.db`, et scripts de migration/export. Voir
`server/CLAUDE.md` pour le détail (stack, routes, schéma des tables).

- **Pipeline données** : la base SQLite est la **source de vérité**.
  `python server/scripts/export_dart.py` (n'exporte que `validated = 1`) régénère
  `lib/historibroc.dart` ; l'app Flutter lit **ce `.dart`**, jamais la `.db`
  (données bundlées au build → offline). Rebuild de l'app indispensable ensuite.
- La base `server/db/historibroc.db` est **versionnée** (source de `listHistoric`) ;
  seuls les backups `*.backup-*.db` sont gitignorés.
- **Secrets** : `server/.env` (clé API Anthropic du validateur) reste gitignoré —
  ne jamais le committer.
- Conventions Python : style propre à `server/` (docstring d'en-tête), l'en-tête
  Dart obligatoire ne s'applique **qu'aux fichiers `.dart`**.

<!-- ════════════════════════════════════════════════════════════════
     FIN DU BLOC CONVENTIONS. Le contenu /init original suit ci-dessous.
     ════════════════════════════════════════════════════════════════ -->

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run on a connected device or emulator
flutter run

# Build
flutter build apk          # Android
flutter build ios          # iOS
flutter build web          # Web

# Analyze (lint)
flutter analyze

# Run tests
flutter test
flutter test test/widget_test.dart   # single test file

# Get/update dependencies
flutter pub get
flutter pub upgrade
```

## Architecture Overview

**cobroc** is a Flutter app for discovering and ranking French *brocantes* (flea markets). It scrapes [brocabrac.fr](https://brocabrac.fr) and presents events ranked by a configurable scoring algorithm.

### Data flow

1. `ManagerPML` (main screen) builds URLs like `https://brocabrac.fr/recherche?ou=<deptCode>&c=bro,vgr,bra&d=<date>` for each department in the active region.
2. `NetworkHelper` (`networking.dart`) fetches each URL, parses HTML with the `html` package, and extracts `application/ld+json` Event schema blocks to build `Brocabrac` objects.
3. `ManagerPML` computes distances, density, and scoring, then sorts and displays events.

### Key classes

- **`Brocabrac`** (`pmltools.dart`) — the core data model for a single brocante event. Fields include location, status (`OK`/`KO`), exposant count, revenue rating, distance from reference point, and density score.
- **`ManageCobrac`** (`pmltools.dart`) — argument wrapper for navigating to detail screens (passes the full list + selected item).
- **`GoToMarket`** (`pmltools.dart`) — holds map trip data (markers, center coords).
- **`Historic`** (`historibroc.dart`) — a hardcoded list of previously-visited brocantes. Used to mark events as "already seen" (`brocDejaVu`). The list (`listHistoric`) is compiled into the binary — no external DB.

### Services (`lib/services/`)

| Service | Responsibility |
|---|---|
| `GeoService` | Haversine distance calculation |
| `ScoringService` | Weighted scoring (exposants, density, revenue, historic, distance) → ranking |
| `FilterService` | Filter brocante list by exposant count category or historic-only |
| `DateService` | Compute next Saturday/Sunday date strings for the date picker |
| `HolidayService` | French public holiday calendar (Pâques, Ascension, etc.) + brocante-day logic (Sam/Dim/Férié); week-level and inter-week navigation |
| `LocationService` | GPS acquisition + reverse geocode to French département |
| `StorageService` | `SharedPreferences` persistence (rayon, scoring weights, active location) |

### Screens

| File | Screen |
|---|---|
| `managerpml.dart` | Main list screen — entry point, orchestrates everything |
| `detailedBrocante.dart` | Detail view for a single brocante (long-press from list) |
| `zee.dart` | Alternative detail view (`DetailBroc`) with historic-analysis panel (`analyzeBrocante`) |
| `monplan.dart` | Interactive map using `flutter_map` + OpenStreetMap tiles |
| `mapcobrac.dart` | Département-grid map view for selecting a custom trip |
| `departements.dart` | France département selector using `interactive_country_map` |
| `datate.dart` | Date picker screen (`ConfigBrocante`) |
| `histeric.dart` | Browse/search the hardcoded historic visits |

### Widgets (`lib/widgets/brocante/`)

- `BrocanteListView` — left panel, full list sorted by distance from reference point
- `BrocanteListReduce` — right panel, filtered list sorted by distance from selected point
- `RayonDialog` — settings dialog for density radius and scoring weights
- `FiltreExposantsDialog` — filter picker by exposant count category

### Models (`lib/models/`)

- `FiltreCategorieExposants` — enum for exposant count filter
- `ConfigLieu` — location preset model

### Static data

- `communestchinos.dart` — `listCommunes`: a large list of French communes with revenue/population data. Used to enrich brocantes with income data for scoring.
- `historibroc.dart` — `listHistoric`: hardcoded visit history.
- `diverspml.dart` — French day/month name arrays and `BreakDate` utility.
- `villes_france.dart` — `listVillesFrance`: 9 911 communes métropolitaines ≥ 1 000 hab. avec coordonnées GPS et département. Utilisée uniquement par le GPS simulé pour afficher les 5 villes les plus proches des coordonnées choisies.

### Location presets

`ManagerPML` has three hardcoded base locations (Larris, Portbail, Loon-Plage) plus a GPS mode. The active location determines which département codes are fetched and which coordinates are used as the distance reference.

### GPS simulé

Accessible via l'icône GPS dans la barre de dates. Permet de simuler une position arbitraire sans bouger physiquement. Persisté via `StorageService.saveGpsSimule / loadGpsSimule` (SharedPreferences).

- L'activation ne change **pas** les départements sélectionnés (MonCoin) — seules les coordonnées de référence (`latitudeRef`, `longitudeRef`, `latitudeSelect`, `longitudeSelect`) sont mises à jour.
- Le dialog contient un **pad 2D draggable** (`GestureDetector` + `CustomPaint`) représentant la silhouette de la France métropolitaine (57 points, classe `_FrancePainter`). L'utilisateur glisse un point orange sur la carte.
- Boutons ± N/S et O/E pour ajustement fin (±0.1°). Convention : N/S `−` = nord, `+` = sud ; O/E `−` = ouest, `+` = est.
- Les 5 villes les plus proches (depuis `listVillesFrance`) se mettent à jour en temps réel pendant le glissement (`onPanUpdate`) via `_cinqVillesProches()`.
- Un tap sur une ville centre le point sur elle.
- Bornes du pad : lat 42.3–51.1°N, lon −4.8–8.2°E.

### Scoring

`ScoringService.calculerScoreOptimal()` combines four weighted criteria (exposants, local density, commune revenue, historic visits) with an optional distance factor. Weights are persisted via `SharedPreferences` and configurable from the settings dialog. The top 3 ranked events are highlighted with gold/silver/bronze colors in the list.

### Liste brocantes (BrocanteListView)

- Brocantes annulées (`brocEventStatus != 'OK'`) affichées en rouge écarlate (`#D50000`) avec préfixe `KO` sur toutes les lignes.
- Classement : médailles 🥇🥈🥉 uniquement pour le top 3, pas de texte de rang.
- Chargement optimisé : `Future.wait()` pour fetch parallèle, 1 seul `setState` final, calcul densité/scoring O(N²) une seule fois après tous les fetches.

### Historic analysis (`zee.dart`)

`analyzeBrocante(ville)` queries `listHistoric` for all past visits to a city and returns a composite score (qualité, taille, potentiel achat, commentaires, note globale). Displayed in the `DetailBroc` detail screen as an analysis panel. Simple keyword-based sentiment from `histAvis`/`histDetail` fields.

### Key dependencies

| Package | Use |
|---|---|
| `http` | HTTP requests to brocabrac.fr |
| `html` | HTML parsing, ld+json extraction |
| `google_maps_flutter` | Native Google Maps (used in `zee.dart` single-marker view) |
| `flutter_map` + `latlong2` | OSM tile maps (`monplan.dart`) |
| `interactive_country_map` | Département selector (`departements.dart`) |
| `geolocator` + `geocoding` | GPS + reverse geocode |
| `shared_preferences` | Settings persistence |
| `diacritic` | Accent-insensitive string comparison |
| `intl` | Date formatting |
| `sqlite3` | Declared dependency (not actively used in current screens) |
quitexit