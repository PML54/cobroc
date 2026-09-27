# Suivi des sessions avec Claude
<!-- Dernière modification : 2026-09-27 -->

> Ce fichier est le point d'entrée pour reprendre le travail avec Claude.
> À lire en début de session, à mettre à jour en fin de session.
> Convention : section `## Session AAAA-MM-JJ` par session, la plus récente en tête.

---

## Session 2026-09-27

### ✅ Fait

- **Abandon DATAtourisme + videgrenier** (décision PML : « je n'en veux plus »). Supprimés :
  - `server/scripts/datatourisme_brocantes.py`
  - `server/scripts/videgrenier.py`
  - `datatourisme.md`
  - variables `DATATOURISME_FLOW_ID` / `DATATOURISME_APP_KEY` de `server/.env.example`
- Notes « brocabrac.fr et datatourisme injoignables par design » **conservées** dans
  `.claude/settings.json` et `docs/CLOUD_SESSIONS.md` (garde-fou réseau / gel légal,
  indépendant des scripts abandonnés).
- **Commit + push** : `bbf564b chore: abandon DATAtourisme + videgrenier` poussé sur `main`.

---

## Session 2026-06-29

### ✅ Fait

**Appli web server (`server/static/index.html`) :**
- Sélecteur d'année (2009 → année courante) déclenche directement le rapport
- Rapport trié par date DESC puis ville ASC
- Validation triplet obligatoire (Visiteur + Date + Ville) — bouton Enregistrer grisé si incomplet
- Nouveaux champs achats : Avis + Vendu (numérique €)
- Carte Qualité : cases Agréable / Non Signalée / À faire à 2
- Zone Dépenses : affiche PML ou FRA selon visiteur, auto-calcul depuis les achats

**DB + serveur (`server/server.py`, `server/db/schema.sql`) :**
- Nouveaux champs : `endroit_salle`, `qualite_agreable`, `qualite_non_signalee`, `qualite_a_faire_a_2`
- Migration automatique au startup (`_migrate_db`)

**Export + app Flutter :**
- `export_dart.py` : bug corrigé — sauts de ligne dans `hist_avis` non échappés → Dart invalide
- 2223 entrées exportées, build iOS OK

**Docs :**
- `cobrocserver.md`, `MAJDB.md`, `specs_agents_domestiques.md` → **supprimés** (obsolètes/doublons)
- Section Dépannage fusionnée dans `server/CLAUDE.md`
- En-têtes de date ajoutés sur tous les `.md` actifs
- `suivi.md` restructuré (ce fichier)

**Git :**
- Ancien `.git` détruit + nouveau repo vierge (à faire depuis terminal — sandbox sans droits)
- Poussé vers `https://github.com/PML54/cobroc.git`

### ⏭️ En attente / à faire

- ~~**DATAtourisme** : flux à réactiver~~ → **abandonné** (voir session 2026-09-27)
- ~~**`server/scripts/videgrenier.py`** : à supprimer~~ → **fait/abandonné** (voir session 2026-09-27)
- **Commit** : les dernières modifs de cette session ne sont pas encore commitées

---

## Session 2026-06-23

### ✅ Fait

- Script `server/scripts/datatourisme_brocantes.py` (stdlib + dotenv) — liste date + ville des brocantes via open data
- Flag `--debug-http` ajouté au script (affiche en-têtes + corps HTTP en erreur)
- Doc `datatourisme.md` créée
- `server/.env.example` : ajout vars `DATATOURISME_APP_KEY`, `DATATOURISME_FLOW_ID`

---

## Session 2026-06-18

### ✅ Fait

- Édition de visites dans l'appli web : carte « Modifier une visite » + bascule POST→PUT
- Doc `server/CLAUDE.md` mise à jour

---

## ⚠️ Secrets (ne jamais committer)

`server/.env` (gitignoré) contient :
- `ANTHROPIC_API_KEY` — validateur agent

Sur nouvelle machine : recréer depuis `.env.example` + `pip install -r requirements.txt` dans `server/`.
