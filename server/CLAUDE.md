# cobroc-server

Serveur REST local pour la base **historibroc** — historique des visites de brocantes de PML et FRA.  
Objectif principal : partager et modifier la base depuis n'importe quelle machine du réseau local.

## Stack

| Composant | Détail |
|-----------|--------|
| Runtime | Python 3.11, venv `.venv/` |
| Framework | FastAPI + Uvicorn |
| Base de données | SQLite `db/historibroc.db` |
| Validation IA | Claude Haiku via `agent/validator.py` |
| Config | `.env` (copie de `.env.example`) |

## Démarrage

Le serveur tourne normalement en tant que **service launchd** (`com.pml.cobroc-server.plist` dans `~/Library/LaunchAgents/`) — relance automatique au login.

```bash
# Arrêt propre (avant mise à jour)
launchctl unload ~/Library/LaunchAgents/com.pml.cobroc-server.plist

# Relance en avant-plan (pour voir les logs)
source .venv/bin/activate
uvicorn server:app --host 0.0.0.0 --port 8765

# Remettre en service automatique
launchctl load ~/Library/LaunchAgents/com.pml.cobroc-server.plist
```

Accès réseau local : `http://192.168.1.11:8765`  
Swagger UI : `http://192.168.1.11:8765/docs`

## Structure des fichiers

```
server.py                           # Application FastAPI — toutes les routes
static/index.html                   # Appli web de saisie d'une visite (servie sur / et /static)
agent/validator.py                  # Agent Claude Haiku : valide chaque entrée avant insertion
db/schema.sql                       # DDL SQLite (tables lieux + historic + index)
db/historibroc.db                   # Base SQLite (~2237 entrées + 672 lieux)
scripts/import_dart.py              # Migration initiale depuis historibroc.dart
scripts/export_dart.py              # Export base → lib/historibroc.dart (projet Flutter cobroc)
scripts/migrate_lieux.py            # Migration 1 : remplace la VIEW lieux par une TABLE, ajoute lieu_id à historic
scripts/migrate_historic_lieux.py   # Migration 2 : peuple lieux depuis historic et relie lieu_id
scripts/migrate_lieu_endroit.py     # Migration 3 : ajoute parking/rues/stade/espace à lieux
requirements.txt                    # fastapi, uvicorn, anthropic, python-dotenv
.env                                # ANTHROPIC_API_KEY + DB_PATH (ne pas commiter)
```

## Table `lieux` — champs

| Champ | Type | Description |
|-------|------|-------------|
| `id` | INTEGER PK | Auto-increment |
| `nom` | TEXT | Nom du marché/événement (ex : "Brocante d'ABLEIGES") |
| `ville` | TEXT | Commune (forme canonique) |
| `ville_normalized` | TEXT | Commune sans accents en majuscules (recherche) |
| `code_postal` | INTEGER | Code postal français |
| `adresse` | TEXT | Lieu précis |
| `recurrence` | TEXT | `"mensuel"`, `"annuel"`, `"ponctuel"`, etc. |
| `parking` | INTEGER 0/1 | Endroit : parking |
| `rues` | INTEGER 0/1 | Endroit : rues |
| `stade` | INTEGER 0/1 | Endroit : stade |
| `espace` | INTEGER 0/1 | Endroit : espace |
| `created_at` | TEXT | `datetime('now')` à l'insertion |

## Table `historic` — champs

| Champ | Type | Description |
|-------|------|-------------|
| `id` | INTEGER PK | Auto-increment |
| `hist_name` | TEXT | `"PML"` ou `"FRA"` |
| `hist_date` | TEXT | Format `AAAA-MM-JJ` |
| `hist_good` | INTEGER 0–5 | Note de la brocante |
| `hist_ville` | TEXT | Commune (MAJUSCULES conseillé) |
| `hist_code_postal` | INTEGER | Code postal français |
| `hist_adresse` | TEXT | Lieu précis |
| `hist_nb_expo` | INTEGER | Nombre d'exposants estimé |
| `hist_pml_dep` | INTEGER | Dépenses PML (€) |
| `hist_fra_dep` | INTEGER | Dépenses FRA (€) |
| `hist_maison_dep` | INTEGER | Dépenses maison (€) |
| `hist_avis` | TEXT | Commentaire libre |
| `hist_detail` | TEXT | Achats détaillés |
| `validated` | INTEGER 0/1 | Approuvé par l'agent Claude |
| `agent_notes` | TEXT | Notes de l'agent après validation |
| `created_at` | TEXT | `datetime('now')` à l'insertion |
| `ville_normalized` | TEXT | Commune sans accents en majuscules (recherche) |
| `lieu_id` | INTEGER FK | Référence vers `lieux.id` (nullable pour anciennes entrées) |
| `heure_arrivee` | TEXT | Heure d'arrivée (format HH:MM) |
| `pluie` | INTEGER 0/1 | Condition météo : pluie |
| `arrivee_tard` | INTEGER 0/1 | Condition : arrivée trop tard |
| `ordre` | INTEGER 1–5 | Ordre de la visite dans la journée (défaut 1) |
| `endroit_parking` | INTEGER 0/1 | Brocante en parking |
| `endroit_champ` | INTEGER 0/1 | Brocante en champ |
| `endroit_stade` | INTEGER 0/1 | Brocante au stade |
| `endroit_place` | INTEGER 0/1 | Brocante sur une place |
| `endroit_rues` | INTEGER 0/1 | Brocante dans les rues |
| `endroit_salle` | INTEGER 0/1 | Brocante en salle |
| `qualite_agreable` | INTEGER 0/1 | Qualité : agréable |
| `qualite_non_signalee` | INTEGER 0/1 | Qualité : non signalée |
| `qualite_a_faire_a_2` | INTEGER 0/1 | Qualité : à faire à 2 |

## Routes API

| Méthode | Route | Description |
|---------|-------|-------------|
| GET | `/lieux` | Liste (filtres : `ville` = **début de ville**, `cp`, `sort`) |
| GET | `/lieux/{id}` | Lieu par ID |
| POST | `/lieux` | Créer un lieu |
| PUT | `/lieux/{id}` | Modifier un lieu |
| DELETE | `/lieux/{id}` | Supprimer (refusé si utilisé dans historic) |
| GET | `/historic` | Liste (filtres : `ville` = **début de ville**, `name`, `validated`, `year`, `sort`, `limit`, `offset`) |
| GET | `/historic/{id}` | Entrée par ID |
| POST | `/historic` | Créer (déclenche validation agent) |
| PUT | `/historic/{id}` | Modifier (re-valide via agent) |
| DELETE | `/historic/{id}` | Supprimer |
| GET | `/export/dart` | Génère `historibroc.dart` en texte brut |
| GET | `/stats` | Total, validés, en attente, répartition PML/FRA |

Le filtre `ville` (sur `/lieux` et `/historic`) matche **en début de nom uniquement** (`{ville}%`), sans accents et insensible à la casse (fonction `NOACCENT`).  
Le filtre `year` (entier, ex. `2026`) filtre sur `hist_date LIKE '2026-%'`.  
Les tris `date_desc` et `date_asc` incluent un **tri secondaire par ville** (`hist_ville COLLATE NOACCENT ASC`).

## Appli web de saisie (`static/index.html`)

Formulaire « Nouvelle visite » servi sur `/` (redirige vers `/static/index.html`). Page HTML/CSS/JS autonome, sans build.

- **En-tête** : sélecteur d'année (2020 → année courante) + bouton 🕐. Pas de titre de page.
- **Icône 🕐** : charge `GET /historic?sort=date_desc&year=<annee>&limit=500` — toutes les visites de l'année sélectionnée, triées par date desc puis ville. Chaque ligne : date · visiteur · ville · lieu · nb exposants · étoiles · commentaire tronqué. Clic → mode édition (`PUT /historic/{id}`). C'est le **seul point d'entrée** pour modifier une visite.
- **Formulaire** : une ligne Date · Heure · Ordre (stepper − n +) · Note (étoiles). Pas de titres de section.
- **Visiteur** : bascule PML / FRA.
- **Lieu** : Ville | Adresse sur une ligne, CP | Nb exposants sur la suivante. Puis **Conditions** (Pluie, Arrivée trop tard) et **Endroit** (Parking / Champ / Stade / Place / Rues, 3 colonnes).
- **Endroit** : stocké dans `historic` (`endroit_*`), pas dans `lieux`.
- **Nouveau lieu** : modale dédiée → `POST /lieux` puis auto-sélection.
- **Détail des achats** : lignes description + prix, recomposées dans `hist_detail` au format `desc=prix€+…`.
- Enregistrement silencieux (pas de bandeau succès). Les erreurs s'affichent en rouge.
- **Contrainte d'unicité** : le triplet (hist_ville, hist_name, hist_date) doit être unique — les doublons sont à nettoyer manuellement via SQLite.

## Variables d'environnement (`.env`)

```
ANTHROPIC_API_KEY=sk-ant-...   # Obligatoire pour la validation agent
DB_PATH=./db/historibroc.db    # Chemin vers la base SQLite
SERVER_HOST=0.0.0.0            # Écoute sur tout le réseau
SERVER_PORT=8765
```

## Agent de validation (Claude Haiku)

Chaque `POST /historic` et `PUT /historic/{id}` appelle `agent/validator.py` qui :
1. Vérifie le format de la date et la cohérence ville/code postal
2. Détecte les doublons potentiels (même ville + date + name)
3. Suggère des corrections (`hist_ville`, `hist_avis`)
4. Retourne `{"approved": bool, "notes": str, "suggestions": {...}}`

Les suggestions approuvées sont appliquées avant insertion.  
**Garde-fous** :
- Champs entiers : la suggestion n'est appliquée que si elle est parsable en `int`.
- Champs libres (`hist_avis`, `hist_detail`, `hist_adresse`) : jamais modifiés par l'agent, ni côté serveur (`NO_SUGGEST`), ni dans le prompt système.
- Le prompt interdit explicitement à Haiku de suggérer des modifications sur les textes libres.

## Export vers l'appli Flutter `cobroc`

L'appli `cobroc` (iPhone surtout, web parfois) **ne lit PAS la base SQLite au runtime**.
Elle consomme un fichier Dart généré, **`lib/historibroc.dart`** (racine du monorepo),
qui contient la classe `Historic` et une liste `listHistoric` en dur (données embarquées
au build → offline). Modifier la `.db` seule ne met donc **rien** à jour.

> Monorepo : ce dossier est `server/` sous la racine `cobroc`. Les commandes
> ci-dessous se lancent depuis `server/` ; l'export écrit dans `../lib/historibroc.dart`.

**Workflow de mise à jour des données de l'appli :**

```bash
# 1. Régénérer le fichier Dart depuis la base (depuis server/)
python3 scripts/export_dart.py            # écrit ../lib/historibroc.dart
# (ou : curl http://localhost:8765/export/dart > ../lib/historibroc.dart)

# 2. Rebuilder/redéployer l'appli Flutter (étape indispensable, données bundlées)
```

Points clés de `scripts/export_dart.py` :
- N'exporte que les entrées **`validated = 1`**. Les saisies du formulaire web sont
  `validated = 0` tant que l'agent ne les a pas approuvées → **elles ne s'exportent pas**.
- Le template de la classe `Historic` (dans le script) doit rester **synchronisé** avec
  ce qu'attend le code Dart de `cobroc` (ex. la méthode statique `matchesVille`, utilisée
  par `detailedBrocante.dart`). Toute régénération **écrase** `historibroc.dart`.
- Les champs enrichis (`heureArrivee`, `pluie`, `arriveeTard`, et l'endroit du lieu
  `parking`/`rues`/`stade`/`espace` via LEFT JOIN `lieux`) sont émis en **paramètres
  nommés optionnels**, et **seulement s'ils sont non-défaut** → les anciennes lignes
  restent inchangées, rétro-compatibles.
- Ces champs sont **transportés** dans les objets `Historic` et **affichés** dans la
  vue d'une visite (`lib/histeric.dart`, badges conditionnels heure/pluie/endroit).
- Valider le fichier généré : `cd .. && dart analyze lib/historibroc.dart`.

## Migrations automatiques

`_migrate_db()` est appelée au startup — elle détecte les colonnes manquantes via `PRAGMA table_info(historic)` et les ajoute avec leur valeur par défaut. Les nouvelles colonnes s'ajoutent à la liste dans `server.py` ; les migrations sont idempotentes (safe à rejouer).

## Commandes utiles

```bash
# Stats rapides
curl http://localhost:8765/stats

# Recherche par ville
curl "http://localhost:8765/historic?ville=PONTOISE&limit=10"

# Export Dart (après ajouts validés)
curl http://localhost:8765/export/dart > ../lib/historibroc.dart

# Réimporter depuis Dart (reset complet)
python3 scripts/import_dart.py
```

## Accès depuis le réseau local

Le serveur démarre avec `--host 0.0.0.0`, ce qui l'expose sur toutes les interfaces réseau.  
Depuis un autre appareil sur le même Wi-Fi/LAN, utiliser l'IP locale du Mac serveur :

```bash
# Trouver l'IP locale
ipconfig getifaddr en0   # Wi-Fi
ipconfig getifaddr en1   # Ethernet
```

Exemple d'accès depuis un autre Mac : `http://192.168.1.X:8765/docs`
