# cobroc-server
<!-- Dernière modification : 2026-09-28 -->

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
static/lieux.html                   # Appli web de gestion des lieux (liste, recherche, création, édition)
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
| `duo` | INTEGER 0/1 | Visite faite à 2 dans une seule voiture (0 = Non par défaut, 1 = Oui) — fait constaté, distinct de `qualite_a_faire_a_2` (recommandation). Base du futur calcul des frais d'essence |

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

> **Séparation lieu / visite** : la création d'un lieu est **dissociée** de la saisie d'une visite.
> `index.html` ne fait que **sélectionner** un lieu existant (`lieu_id` obligatoire, plus de saisie libre) ;
> toute création ou modification de lieu passe par `lieux.html`.

- **En-tête** : sélecteur d'année (2020 → année courante) + bouton 📍 (page Lieux) + bouton 🕐. Pas de titre de page.
- **Icône 🕐** : charge `GET /historic?sort=date_desc&year=<annee>&limit=500` — toutes les visites de l'année sélectionnée, triées par date desc puis ville. Chaque ligne : date · visiteur · ville · lieu · nb exposants · étoiles · commentaire tronqué. Clic → mode édition (`PUT /historic/{id}`). C'est le **seul point d'entrée** pour modifier une visite.
- **Formulaire** : une ligne Date · Heure · Ordre (stepper − n +) · Note (étoiles). Pas de titres de section.
- **Visiteur** : bascule PML / FRA.
- **Lieu** : Ville · Code postal · Adresse sur une ligne. Puis **Nb exposants + Conditions** (Pluie / Trop tard / **Duo** « même voiture », cases à cocher) sur une ligne, et **Endroit** (Parking / Champ / Stade / Place / Rues / Salle) sur une ligne.
- Ordre des rubriques : Avis → **Détail des achats** (toujours affiché) → Qualité → Dépenses.
- **Règle MAISON** : un objet du détail dont l'avis vaut `MAISON` (insensible à la casse) n'est pas compté dans les calculs de dépense/marge (`sumAchatsPrix`, `margeVisite`, `somme_detail`).
- **Endroit** : stocké dans `historic` (`endroit_*`), pas dans `lieux`.
- **Lieu obligatoire** : le champ Ville est un **pur sélecteur** alimenté par `GET /lieux?ville=…`. Tant qu'aucun lieu n'est sélectionné (`selectedLieuId === null`), le bouton Enregistrer reste grisé. CP et Adresse sont en lecture seule, remplis depuis le lieu.
- **Aucun résultat** : le dropdown affiche un lien « Créer le lieu → » vers `/static/lieux.html?ville=<VILLE>&new=1` (ouvre l'éditeur pré-rempli). Plus de modale de création dans `index.html`.
- **Conséquence sur les anciennes visites** : une entrée à `lieu_id` NULL ne peut plus être réenregistrée sans lui associer un lieu — l'édition force donc le backfill de `lieu_id`.
- **Détail des achats** : lignes description + prix, recomposées dans `hist_detail` au format `desc=prix€+…`.
- Enregistrement silencieux (pas de bandeau succès). Les erreurs s'affichent en rouge.
- **Contrainte d'unicité** : le triplet (hist_ville, hist_name, hist_date) doit être unique — les doublons sont à nettoyer manuellement via SQLite.

## Appli web des lieux (`static/lieux.html`)

Page autonome servie sur `/static/lieux.html`, même charte que `index.html`. Seul point d'entrée pour créer ou modifier un lieu.

- **En-tête** : bouton ← (retour saisie visite), champ de recherche par ville (forcé en majuscules, debounce 250 ms), bouton ＋ (nouveau lieu).
- **Liste** : toujours en **ordre alphabétique** (`sort=ville_asc&limit=1000`) — liste complète sans recherche (678 lieux à ce jour, sous la limite API de 1000), filtrée par début de ville sinon. Une ligne = ville · CP · nom · adresse · nb visites. Clic → éditeur pré-rempli.
- **Éditeur** : même carte pour création (`POST /lieux`) et modification (`PUT /lieux/{id}`), distinguées par `editingId`. Champs : Ville + CP (obligatoires), Adresse, Nom, Récurrence, Endroit (parking / rues / stade / espace — champs de la table `lieux`, distincts des `endroit_*` de `historic`).
- **Pas de suppression** dans l'UI — `DELETE /lieux/{id}` reste disponible via l'API.
- **Paramètres d'URL** : `?ville=XXX` pré-remplit la recherche, `?new=1` ouvre directement l'éditeur en création.

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
- `duo` (visite faite à 2) est exporté de la même façon (`duo: 1` seulement si Oui).
  Il est **transporté** dans `Historic` mais **pas encore affiché ni utilisé** côté Flutter.
  L'export tolère une base non migrée (colonne `duo` absente ⇒ 0).
- Ces champs sont **transportés** dans les objets `Historic` et **affichés** dans la
  vue d'une visite (`lib/histeric.dart`, badges conditionnels heure/pluie/endroit).
- Valider le fichier généré : `cd .. && dart analyze lib/historibroc.dart`.

## ⚠️ Bonne pratique — committer la base AVANT toute session cloud (leçon apprise)

La base `db/historibroc.db` est **versionnée dans git**, mais les saisies faites via
l'appli web s'y écrivent **sans commit automatique**. Une base modifiée mais **non
committée** est une simple modif de la copie de travail — donc candidate à un
`git stash`.

**Incident du 2026-09-27 (à ne pas reproduire).** Un lancement de *Claude Code on the
web* a déclenché une **téléportation** du repo vers le cloud. Pour partir d'une copie
de travail propre, la téléportation a fait un **`git stash` automatique**
(« Teleport auto-stash ») : la base avec toutes les visites de l'été (25/07 → 20/09)
est partie dans le stash, et la copie de travail est revenue au **dernier commit de la
base (21 juillet)**. Résultat : trou apparent 19/07 → aujourd'hui dans la base live.
Données **récupérées** depuis `stash@{0}` (`git show 'stash@{0}:server/db/historibroc.db'`),
fusionnées avec les saisies du jour, puis **la base a été committée** pour la rendre durable.

**Règles :**
- **Committer la base avant toute session cloud / téléportation** :
  `git add server/db/historibroc.db && git commit -m "data: snapshot base avant session cloud"`.
  Une fois committée, elle n'est plus concernée par un stash/téléportation.
- Committer aussi **régulièrement** après une série de saisies (la base est la source de vérité).
- **Réflexe de récupération** après une manip git suspecte : `git stash list`. Si un
  « auto-stash » traîne, les modifs perdues y sont probablement — extraire sans écraser
  la base live via `git show 'stash@{0}:server/db/historibroc.db' > /tmp/x.db` puis inspecter/fusionner.

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

## Dépannage

### « Unexpected token 'I', "Internal S"… is not valid JSON »

L'appli web reçoit une **500 Internal Server Error** (texte brut) au lieu de JSON. Causes fréquentes :

1. **Clé API invalide / révoquée** → vérifier `server/.env`, puis redémarrer le serveur (la clé est lue au boot).
2. **Mauvais process sur le port 8765** (ex. vieux serveur depuis un autre dossier) :
   ```bash
   lsof -nP -iTCP:8765 -sTCP:LISTEN   # PID + dossier de travail
   lsof -p <PID> | grep cwd
   kill <PID>                          # tuer, relancer depuis server/
   ```
3. **Tester la clé directement** :
   ```bash
   curl -s https://api.anthropic.com/v1/messages \
     -H "x-api-key: $(grep ^ANTHROPIC_API_KEY= .env | cut -d= -f2-)" \
     -H "anthropic-version: 2023-06-01" -H "content-type: application/json" \
     -d '{"model":"claude-haiku-4-5-20251001","max_tokens":16,"messages":[{"role":"user","content":"ping"}]}'
   ```
4. Toujours lire le **traceback uvicorn** pour la cause exacte.

### `sqlite3.ProgrammingError: Incorrect number of bindings`

Désynchronisation entre les colonnes listées dans l'INSERT/UPDATE et les paramètres `:xxx`. Vérifier que tout nouveau champ est ajouté aux deux endroits dans `server.py`.

### `address already in use` au démarrage

launchd a relancé uvicorn automatiquement. Faire d'abord `launchctl unload` avant de lancer manuellement (voir START.md).
