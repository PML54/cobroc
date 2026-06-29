# cobroc-server — outillage données & transfert vers cobroc

> Document de référence : à quoi sert `server/`, comment l'utiliser, et **comment
> les informations remontent jusqu'à l'application Flutter `cobroc`**.
>
> Anciennement repo séparé `cobroc-server`, désormais intégré dans le monorepo
> `cobroc` sous **`server/`** (via `git subtree`). Voir aussi `server/CLAUDE.md`
> pour le détail des routes et du schéma SQL.

---

## 1. Vue d'ensemble

`server/` est l'outillage **data** du projet. Il sert à **saisir, valider et stocker**
l'historique des visites de brocantes (PML / FRA), puis à **exporter** ces données
vers l'application Flutter.

| Composant | Rôle |
|-----------|------|
| Serveur FastAPI (`server/server.py`) | API REST + appli web de saisie d'une visite |
| Base SQLite (`server/db/historibroc.db`) | **Source de vérité** des données (tables `lieux` + `historic`) |
| Agent Claude (`server/agent/validator.py`) | Valide chaque saisie avant insertion (cohérence ville/CP, doublons…) |
| Scripts (`server/scripts/`) | Migrations + **export** vers le `.dart` consommé par l'app |

Point clé : **l'app Flutter ne lit jamais la base SQLite au runtime.** Elle embarque
un fichier Dart généré (`lib/historibroc.dart`), donc 100 % offline. Modifier la
`.db` ne change rien dans l'app tant qu'on n'a pas (a) ré-exporté le `.dart`, (b)
rebuildé l'app.

---

## 2. Le transfert des infos vers cobroc (le point central)

### Chaîne complète des données

```
┌─────────────────────┐   POST /historic    ┌──────────────────────┐
│  Appli web de saisie │ ──────────────────▶ │  Agent Claude         │
│  static/index.html   │                     │  validator.py         │
└─────────────────────┘                     └──────────┬───────────┘
                                                        │ approved + corrections
                                                        ▼
                                          ┌──────────────────────────┐
                                          │  SQLite (SOURCE DE VÉRITÉ)│
                                          │  server/db/historibroc.db │
                                          │  validated = 1 / 0        │
                                          └──────────┬────────────────┘
                                                     │  export_dart.py
                                                     │  (n'exporte QUE validated = 1)
                                                     ▼
                                          ┌──────────────────────────┐
                                          │  lib/historibroc.dart     │
                                          │  classe Historic +        │
                                          │  List<Historic> listHistoric│
                                          └──────────┬────────────────┘
                                                     │  flutter build / run
                                                     ▼
                                          ┌──────────────────────────┐
                                          │  App cobroc (iPhone/web)  │
                                          │  données bundlées, offline│
                                          └───────────────────────────┘
```

### Règles à retenir

1. **La base SQLite `server/db/historibroc.db` est la source de vérité.**
   Elle est **versionnée** dans le monorepo (c'est la source de `listHistoric`).
   Seuls les backups `*.backup-*.db` sont gitignorés.

2. **Seules les entrées `validated = 1` sont exportées.** Une saisie faite via
   l'appli web part en `validated = 0` tant que l'agent Claude ne l'a pas approuvée.
   → une saisie non validée **n'apparaît pas** dans l'app.

3. **`lib/historibroc.dart` est entièrement régénéré** à chaque export (écrasement).
   Ne pas l'éditer à la main : toute modif manuelle serait perdue au prochain export.

4. **Rebuild obligatoire.** Les données sont compilées dans le binaire ; après
   un export, il faut rebuild/redéployer l'app pour que les changements soient visibles.

5. **Champs enrichis rétro-compatibles.** Les champs optionnels (heure d'arrivée,
   pluie, arrivée tardive, endroit du lieu via `lieux` : parking/rues/stade/espace)
   sont émis en **paramètres nommés optionnels** et **seulement si non-défaut** →
   les anciennes lignes restent inchangées. Affichés dans `lib/histeric.dart`.

---

## 3. Démarrer le serveur

> ⚠️ **Toujours lancer depuis `server/`** : `server.py` utilise des chemins
> relatifs (`db/schema.sql`, `db/historibroc.db`) et `load_dotenv()` charge le
> `.env` du répertoire courant. Lancé d'ailleurs → mauvaise base ou clé non chargée.

```bash
cd /Users/pml/StudioProjects/cobroc/server
python3.11 -m venv .venv                   # première fois seulement
source .venv/bin/activate
pip install -r requirements.txt            # première fois (fastapi, uvicorn, anthropic, python-dotenv)
uvicorn server:app --host 0.0.0.0 --port 8765 --reload
```

- Appli de saisie : `http://localhost:8765/`
- Swagger / API docs : `http://localhost:8765/docs`
- Accès depuis un autre appareil du LAN : `http://<IP_DU_MAC>:8765`
  (IP locale : `ipconfig getifaddr en0`)

**Pré-requis : `server/.env`** (gitignoré, jamais committé) :

```
ANTHROPIC_API_KEY=sk-ant-api03-...   # requis pour la validation agent
DB_PATH=./db/historibroc.db
SERVER_HOST=0.0.0.0
SERVER_PORT=8765
```

### Démarrage automatique au login (macOS — LaunchAgent)

Le serveur peut démarrer tout seul à l'ouverture de session (et se relancer s'il
crashe) via un **LaunchAgent** : `~/Library/LaunchAgents/com.pml.cobroc-server.plist`.

> ⚠️ Un LaunchAgent démarre **à la connexion de l'utilisateur**, pas au boot avant
> login (un LaunchDaemon root serait inadapté : il faut le venv et les fichiers de
> l'utilisateur). En pratique : reboot → login → serveur dispo sur `localhost:8765`.

Points clés du plist :
- lance `server/.venv/bin/uvicorn server:app --host 0.0.0.0 --port 8765` ;
- `WorkingDirectory` = `server/` (**indispensable** : chemins relatifs `db/`, `.env`) ;
- `RunAtLoad` (démarre au login) + `KeepAlive` (relance si arrêt) + `ThrottleInterval 10` ;
- logs dans `~/Library/Logs/cobroc-server.log`.

> Le plist vit dans `~/Library/LaunchAgents` (**hors dépôt git**) : c'est de la config
> machine locale, normal qu'il ne soit pas versionné.

Commandes de gestion (`gui/<UID>`, UID = `id -u`, ici `501`) :

```bash
# (ré)installer / charger
launchctl bootstrap gui/501 ~/Library/LaunchAgents/com.pml.cobroc-server.plist
launchctl enable    gui/501/com.pml.cobroc-server

# état / logs
launchctl print gui/501/com.pml.cobroc-server | grep -E "state|pid"
tail -f ~/Library/Logs/cobroc-server.log

# redémarrer / arrêter maintenant (sans reboot)
launchctl kickstart -k gui/501/com.pml.cobroc-server   # redémarre
launchctl bootout      gui/501/com.pml.cobroc-server   # arrête + décharge

# désactiver le démarrage auto définitivement
launchctl bootout gui/501/com.pml.cobroc-server
rm ~/Library/LaunchAgents/com.pml.cobroc-server.plist
```

> Quand l'agent tourne, ne pas lancer un second `uvicorn` à la main sur le port 8765
> (conflit de port).

---

## 4. Export en pratique — les commandes

> ⚠️ `export_dart.py` n'utilise que la **bibliothèque standard** Python
> (`sqlite3`, `argparse`, `datetime`, `pathlib`). Pour **juste exporter** la base
> existante, **pas besoin de venv, ni du serveur, ni de la clé API**. Le venv +
> `.env` ne servent qu'à **saisir/valider** de nouvelles visites (§3).

### Export simple (cas courant — la base a déjà des entrées validées)

```bash
cd /Users/pml/StudioProjects/cobroc/server
python3 scripts/export_dart.py            # lit db/historibroc.db → écrit ../lib/historibroc.dart
```

### Vérifier + rebuild

```bash
cd /Users/pml/StudioProjects/cobroc
dart analyze lib/historibroc.dart         # contrôle que le .dart généré est sain
flutter run                               # ou : flutter build apk / ios / web
```

### Tout en un bloc

```bash
cd /Users/pml/StudioProjects/cobroc/server && python3 scripts/export_dart.py \
  && cd .. && dart analyze lib/historibroc.dart \
  && flutter run
```

### Variantes utiles

```bash
# base ou sortie personnalisées
python3 scripts/export_dart.py --db db/historibroc.db --out ../lib/historibroc.dart

# variante via l'API (seulement si le serveur tourne)
curl http://localhost:8765/export/dart > ../lib/historibroc.dart

# voir ce qui changerait AVANT de committer
cd /Users/pml/StudioProjects/cobroc && git diff lib/historibroc.dart
```

> Rappel : `python3 scripts/export_dart.py` n'exporte que `validated = 1`, écrase
> `lib/historibroc.dart`, et **le rebuild Flutter est indispensable** (données bundlées).

---

## 5. Scripts disponibles (`server/scripts/`)

| Script | Rôle |
|--------|------|
| `export_dart.py` | **Base → `lib/historibroc.dart`** (uniquement `validated = 1`) |
| `import_dart.py` | Import initial / reset complet depuis le `.dart` |
| `migrate_lieux.py` | VIEW `lieux` → TABLE + `lieu_id` sur `historic` |
| `migrate_historic_lieux.py` | Peuple `lieux` depuis `historic` et relie `lieu_id` |
| `migrate_lieu_endroit.py` | Ajoute parking / rues / stade / espace à `lieux` |
| `migrate_dates.py`, `migrate_historic_conditions.py` | Migrations de données |
| `analyze_avis.py`, `normalize_comments.py` | Nettoyage / analyse des commentaires |

> ⚠️ Le template de la classe `Historic` dans `export_dart.py` doit rester
> **synchronisé** avec ce qu'attend le code Dart (ex. `matchesVille` utilisée par
> `lib/detailedBrocante.dart`). Toute désync casse la compilation côté app.

---

## 6. Secrets & sécurité

- `server/.env` (clé API Anthropic) est **gitignoré** — ne jamais le committer.
- `server/.env.example` ne doit contenir qu'un **placeholder**, pas de vraie clé.
- Toute clé qui se retrouve dans un commit doit être considérée comme **compromise**
  et **révoquée** dans la console Anthropic (`console.anthropic.com/settings/keys`).

---

## 7. L'ancien repo `cobroc-server` est-il encore utile ?

**Non pour le travail courant** : tout l'outillage (serveur, scripts, base versionnée,
agent) vit désormais dans `server/`. L'ancien dépôt a été **archivé** en
`~/StudioProjects/cobroc-server.ARCHIVE` (purement local, jamais poussé) — il ne sert
plus qu'éventuellement de **référence d'historique git** (le subtree a écrasé
l'historique détaillé en un commit). Ne pas y relancer de serveur : il porte l'ancien
`.env` (clé révoquée) → voir §8.

---

## 8. Dépannage

### « Erreur réseau : Unexpected token 'I', "Internal S"… is not valid JSON »

L'appli web de saisie a reçu une **500 Internal Server Error** (texte brut) au lieu de
JSON lors d'un `POST /historic`. Une exception remonte côté serveur, le plus souvent
dans l'appel à l'agent de validation Anthropic. Causes fréquentes :

1. **Clé API invalide / révoquée** → l'API renvoie 401, l'exception n'est pas gérée → 500.
   - Vérifier que `server/.env` contient une clé **valide** et que le serveur a été
     **redémarré** après tout changement de clé (la clé est lue au boot via
     `load_dotenv()`, un process déjà lancé garde l'ancienne en mémoire).
   - Piège classique : un **vieux serveur** tourne encore (ex. lancé depuis
     `cobroc-server.ARCHIVE` avec l'ancien `.env`). Vérifier qui écoute :
     ```bash
     lsof -nP -iTCP:8765 -sTCP:LISTEN     # PID du process
     lsof -p <PID> | grep cwd             # depuis quel dossier il tourne
     kill <PID>                           # tuer le mauvais, relancer depuis server/ (§3)
     ```
   - Tester la clé directement (hors serveur) :
     ```bash
     curl -s https://api.anthropic.com/v1/messages \
       -H "x-api-key: $(grep ^ANTHROPIC_API_KEY= server/.env | cut -d= -f2-)" \
       -H "anthropic-version: 2023-06-01" -H "content-type: application/json" \
       -d '{"model":"claude-haiku-4-5-20251001","max_tokens":16,"messages":[{"role":"user","content":"ping"}]}'
     ```

2. **Lire la vraie cause** : toujours regarder le traceback du serveur
   (terminal `uvicorn`, ou le fichier de log si lancé en arrière-plan).

### Au démarrage : `sqlite3.OperationalError: table historic already exists`

`schema.sql` est un dump (sans `IF NOT EXISTS`). `_init_db()` ne l'applique désormais
**que si la base est vierge** ; si l'erreur réapparaît, c'est une version de `server.py`
antérieure à ce correctif. Lancer depuis `server/` avec le code à jour.

### Lancer le serveur correctement

Voir §3 : **depuis `server/`**, venv activé, deps installées.
