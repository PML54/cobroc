# Suivi des sessions avec Claude
<!-- Dernière modification : 2026-09-28 -->

> Ce fichier est le point d'entrée pour reprendre le travail avec Claude.
> À lire en début de session, à mettre à jour en fin de session.
> Convention : section `## Session AAAA-MM-JJ` par session, la plus récente en tête.

---

## Session 2026-09-28

Session de **familiarisation avec Claude Code on the web** (cloud sessions), doublée
d'un livrable concret. Menée depuis le Mac (session continuée depuis le cloud).

### ✅ Fait

**1. Tests unitaires de `_is_true_duplicate`** (`server/tests/test_is_true_duplicate.py`).
11 cas, **11/11 passés** avec le venv local (`server/.venv`). Couvre les 4 requis
(doublon exact, PML vs FRA même ville/date → False, normalisation ville Nîmes/NIMES,
liste vide) + compléments (strip des 3 champs, casse visiteur, doublon non-premier,
champs manquants). `validator.py` **non modifié**.
- La rustine initiale (`os.environ.setdefault("ANTHROPIC_API_KEY", ...)` avant
  l'import, car `validator.py` construisait le client Anthropic au niveau module)
  a été **retirée ensuite** grâce au lazy init → voir point 3.

**2. Deux mémos durables dans `docs/CLOUD_SESSIONS.md`** :
- Cycle terminal↔cloud : `--cloud` (crée, TTY requis) vs `--teleport` (rapatrie,
  arbre propre requis) ; règle « push ≠ commit » ; séquence de référence.
- **Constat empirique** : `claude --cloud` depuis ce repo part en **bundle**
  (`git clone /home/user/.seed.bundle`), **pas** en clone réseau → `origin` absent,
  push impossible sans `git remote add`. Installer l'App GitHub *sur le repo* **n'a
  pas suffi** (testé). Mode clone exigerait de connecter claude.ai **via l'App
  GitHub** (onboarding), pas `/web-setup`.

**3. Lazy init du client Anthropic** (`server/agent/validator.py`). `_client =
Anthropic(...)` au niveau module (eager) → remplacé par `_client = None` +
`_get_client()` (construction à la demande, une seule fois) ; appel via
`_get_client().messages.create(...)`. Effet : importer les fonctions pures
n'exige plus `ANTHROPIC_API_KEY` (erreur clé différée au 1er appel réel
d'inference), et la **rustine du test a été supprimée**. Vérifié : import sans
clé OK, `_get_client()` sans clé lève `KeyError` à l'appel (voulu), test
**11/11 sans clé**. Pas d'appel API réseau réel (hors périmètre). Pas de
régression serveur (`server.py` appelle `validate_entry`, inchangé).

### 🧠 Leçons cloud (à coût ~nul cette fois)

- Un commit **non poussé** dans une VM cloud éphémère est **perdu** quand la session
  s'éteint (revécu : la 1ʳᵉ session `_is_true_duplicate` a été perdue, test recréé
  en local). Confirme la leçon du 27/09.
- Le **bundling** est une décision **côté client** (avant démarrage VM), **sans
  rapport** avec la policy réseau Trusted (qui ne bloque que `brocabrac.fr`).

### 🧾 Commits poussés sur `main`
`a3aa61f` mémo cycle cloud · `fdcaece` tests `_is_true_duplicate` ·
`67f0fa6` constat bundle · `908efea` maj suivi · `942c32f` lazy init validator ·
`<ce commit>` maj suivi (lazy init en Fait).

### ⏭️ Reste à faire
- **Rebuild app Flutter** (`flutter build ios`) — toujours en attente (données iPhone).
- **Mode clone cloud** (optionnel) — reconnecter GitHub via l'App dans les settings
  claude.ai si on veut réutiliser le cloud sérieusement.
- **Promo crédits cloud** : 250 $ (Max) à réclamer avant le **7 oct.**, expire **4 nov.**

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
