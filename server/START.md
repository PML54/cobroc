# cobroc-server — démarrage rapide
<!-- Dernière modification : 2026-06-29 -->

## Service launchd (mode normal)

Le serveur tourne en tant que service launchd (`com.pml.cobroc-server`) —
il se relance automatiquement au login et après un `kill` simple.

**Arrêt propre :**
```bash
launchctl unload ~/Library/LaunchAgents/com.pml.cobroc-server.plist
```

**Remise en service automatique :**
```bash
launchctl load ~/Library/LaunchAgents/com.pml.cobroc-server.plist
```

**Relance en avant-plan (pour voir les logs/erreurs) :**
```bash
launchctl unload ~/Library/LaunchAgents/com.pml.cobroc-server.plist
cd ~/StudioProjects/cobroc/server
source .venv/bin/activate
uvicorn server:app --host 0.0.0.0 --port 8765
# Ctrl+C pour stopper, puis :
launchctl load ~/Library/LaunchAgents/com.pml.cobroc-server.plist
```

**Accès réseau local (famille, WiFi) :**
```
http://192.168.1.11:8765
```

---


## 1. Installation (une seule fois)

```bash
cd ~/StudioProjects/cobroc-server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# → éditer .env : mettre ta clé ANTHROPIC_API_KEY
```

## 2. Migration initiale (une seule fois)

```bash
source .venv/bin/activate
python3 scripts/import_dart.py
# affiche : 2237 entrées insérées dans db/historibroc.db
```

## 3. Démarrer le serveur

```bash
source .venv/bin/activate
uvicorn server:app --host 0.0.0.0 --port 8765 --reload
```

Le serveur est accessible depuis l'autre Mac à `http://<IP_MAC_SERVEUR>:8765`

## 4. Tester

```bash
# Stats
curl http://localhost:8765/stats

# Liste des 5 dernières entrées
curl "http://localhost:8765/historic?limit=5"

# Ajouter une entrée (l'agent valide automatiquement)
curl -X POST http://localhost:8765/historic \
  -H "Content-Type: application/json" \
  -d '{"hist_name":"PML","hist_date":"01/06/2026","hist_good":3,
       "hist_ville":"PONTOISE","hist_code_postal":95300,
       "hist_adresse":"Place du Marché","hist_nb_expo":80,
       "hist_pml_dep":25,"hist_fra_dep":0,"hist_maison_dep":0,
       "hist_avis":"Belle brocante, bien fournie","hist_detail":"Livre=3€"}'
```

## 5. Exporter vers historibroc.dart (après ajouts validés)

```bash
python3 scripts/export_dart.py
# → écrit lib/historibroc.dart dans le projet cobroc
# → tu rebuilds ensuite : flutter build apk
```

## 6. API complète

Swagger UI disponible à : `http://localhost:8765/docs`
