# Suivi des sessions avec Claude
<!-- Dernière modification : 2026-09-27 -->

> Ce fichier est le point d'entrée pour reprendre le travail avec Claude.
> À lire en début de session, à mettre à jour en fin de session.
> Convention : section `## Session AAAA-MM-JJ` par session, la plus récente en tête.

---

## Session 2026-09-27

### ✅ Fait

**1. Abandon DATAtourisme + videgrenier** (décision PML : « je n'en veux plus »). Supprimés :
`server/scripts/datatourisme_brocantes.py`, `server/scripts/videgrenier.py`,
`datatourisme.md`, variables `DATATOURISME_*` de `server/.env.example`.
Notes « injoignables par design » **conservées** dans `.claude/settings.json` et
`docs/CLOUD_SESSIONS.md` (garde-fou réseau / gel légal).

**2. 🚨 Incident perte de données + récupération (le gros morceau).**
Symptôme : plus aucune visite entre le 19/07 et aujourd'hui dans la base live.
- **Cause** : un lancement de *Claude Code on the web* avait **téléporté** le repo →
  `git stash` automatique (« Teleport auto-stash ») des modifs non committées, dont la
  base `historibroc.db`. La copie de travail était revenue à l'état committé du 21/07.
- **Récupération** : données d'été retrouvées dans le stash, fusionnées avec les saisies
  du jour (nouveaux id pour éviter la collision). Base restaurée : été (25/07→20/09) + jour.
- **Leçon consignée** dans `server/CLAUDE.md` : **committer la base AVANT toute session cloud**
  (une base non committée est stashée/perdue par la téléportation). Réflexe : `git stash list`.

**3. Récupération complète du stash droppé.** Le `git stash drop` avait aussi fait tomber
d'autres modifs non committées. Commit `1c4f55d` re-sécurisé par tag, puis restaurés :
`server/static/index.html` (feature achats/ventes), `normalize_detail.py`,
`recompute_depenses.py`, `AGENTS.md`, `analysis_options.yaml`, exports CSV, `pubspec.lock`.

**4. Feature bilan achats/ventes (`server/static/index.html`).** Panneau récent (🕐) :
🟢 `+marge€` (revendu avec bénéfice), 🔴 `marge€` (revendu à perte), 🔴 `-achat€`
(**nouveau** : achats mais rien revendu → dépense totale en rouge). Sans chiffre seulement
si aucun achat détaillé.

**5. Validation des 21 entrées en attente.** Toutes des faux positifs « doublon » =
visites conjointes PML+FRA (même ville/date, visiteurs différents). Validées manuellement.
Base : **2265 visites, 0 pending**.

**6. Correctif règle de doublon (`server/agent/validator.py`).** Détection déléguée au LLM
(Haiku) → refusait à tort les sorties à deux. Corrigé : détection **déterministe**
(`_is_true_duplicate` sur `hist_name`+`hist_date`+ville normalisée), prompt qui retire ce
jugement au LLM et rappelle que PML≠FRA. **Testé en réel** : visite conjointe acceptée,
vrai doublon bloqué.

**7. Export + snapshot.** `export_dart.py` relancé → `lib/historibroc.dart` régénéré
(`dart analyze` clean). Base committée à jour.

### 🧾 Commits poussés sur `main`
`bbf564b` abandon DATAtourisme/videgrenier · `5327f15` suivi · `6258cae` restauration base ·
`c3f9e2f` leçon session cloud · `f51882b` restauration complète stash · `3723225` feature dépense rouge ·
`c1ed659` + `3a4ce5e` export/validation · `3ca11e2` fix doublon déterministe · `e582ca8` snapshot base.

### ⏭️ Reste à faire
- **Rebuild app Flutter** (`flutter build ios`) pour propager les données sur l'iPhone.
- (Optionnel) corriger la phrase tronquée dans le message du commit `3ca11e2` (cosmétique).

### 🛟 Backups locaux (gitignorés) créés ce jour
`historibroc.backup-2609271621-{LIVE,STASH}-*.db`, `historibroc.backup-2609271953-avant-validation-21.db`.

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
