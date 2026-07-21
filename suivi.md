# Suivi des sessions avec Claude
<!-- Dernière modification : 2026-06-29 -->

> Ce fichier est le point d'entrée pour reprendre le travail avec Claude.
> À lire en début de session, à mettre à jour en fin de session.
> Convention : section `## Session AAAA-MM-JJ` par session, la plus récente en tête.

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

- **DATAtourisme** : flux `cobroc-flux` (`fc4aa6312d18f42f438d0780a99e97ac`) à (ré)activer sur `diffuseur.datatourisme.fr` — génération désactivée pour inactivité (HTTP 503 depuis le 18/06)
- **`server/scripts/videgrenier.py`** : brouillon inutilisable (robots.txt interdit le scraping) → à supprimer
- **Commit** : les dernières modifs de cette session ne sont pas encore commitées

### ❓ Questions en suspens

- Zone géographique du flux DATAtourisme (Île-de-France ? départements précis ?) — à confirmer sur le portail

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
- `DATATOURISME_APP_KEY` — clé DATAtourisme
- `DATATOURISME_FLOW_ID=fc4aa6312d18f42f438d0780a99e97ac`

Sur nouvelle machine : recréer depuis `.env.example` + `pip install -r requirements.txt` dans `server/`.
