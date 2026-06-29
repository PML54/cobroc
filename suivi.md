# Suivi — reprise de session

> À relire à la prochaine ouverture. Dernière mise à jour : **2026-06-23**.
> Contexte : session où l'on a (1) ajouté l'édition de visites dans l'appli web du
> serveur, et (2) mis en place un script DATAtourisme pour lister des brocantes.

## ⏭️ À FAIRE EN PRIORITÉ À LA REPRISE

**Activer la génération du flux DATAtourisme sur le portail diffuseur.**

Le 503 dure depuis le 18/06. Le mode `--debug-http` (ajouté le 23/06) a révélé la
cause exacte renvoyée par DATAtourisme :

> *« La génération du flux n'a pas encore été **programmée** ou a été **désactivée
> suite à une période d'inactivité** »*

Ce n'est donc **pas** un délai de génération à attendre : il faut agir sur le
**portail web `diffuseur.datatourisme.fr`** (impossible en ligne de commande) :
- ouvrir le flux `cobroc-flux` (`fc4aa6312d18f42f438d0780a99e97ac`) ;
- **(ré)activer / programmer la génération** (et vérifier qu'il n'est pas désactivé
  pour inactivité) ;
- au passage, confirmer **zone géographique + type de POI** (cf. question en suspens)
  et que l'application `cobroc` est bien rattachée avec la bonne `APP_KEY`.

Une fois la génération programmée, l'archive se construit la nuit suivante. Retester
depuis `server/` :

```bash
.venv/bin/python scripts/datatourisme_brocantes.py --debug-http   # message exact si encore en erreur
.venv/bin/python scripts/datatourisme_brocantes.py --inspect 2    # voir la vraie structure JSON-LD
.venv/bin/python scripts/datatourisme_brocantes.py                # liste date + ville
```

- Si encore **HTTP 503** → relancer avec `--debug-http` et lire le message renvoyé.
- Si ça marche → **coller la sortie de `--inspect 2`** pour que je vérifie/ajuste
  l'extraction (`_dates`, `_ville_cp`, `_is_brocante` dans le script). Les noms de
  propriétés JSON-LD n'ont **pas encore été validés sur données réelles**.

## ⚠️ SI CHANGEMENT DE MACHINE

Les secrets ne sont **pas versionnés** (`server/.env` est gitignoré). Sur une
nouvelle machine, il faudra **recréer `server/.env`** à partir de `.env.example` et
y remettre :
- `ANTHROPIC_API_KEY` (validateur agent du serveur)
- `DATATOURISME_APP_KEY` (clé de l'application DATAtourisme `cobroc`)
- `DATATOURISME_FLOW_ID=fc4aa6312d18f42f438d0780a99e97ac` (déjà dans .env.example en placeholder)

Penser aussi à recréer le venv `server/.venv/` (`pip install -r requirements.txt`).
Le script DATAtourisme n'utilise que la stdlib + `python-dotenv`.

## ✅ FAIT CETTE SESSION

### 1. Édition de visites dans l'appli web du serveur
- `server/static/index.html` : ajout d'une carte « Modifier une visite existante »
  (recherche par ville → charge la visite → bascule `POST`→`PUT /historic/{id}`).
  Backend `PUT` déjà existant. **Testé OK** (round-trip PUT, agent re-valide).
- Doc mise à jour dans `server/CLAUDE.md`.

### 2. Script DATAtourisme (brocantes date + ville)
- Source vide-greniers.org **écartée** (`robots.txt: Disallow: /` + risque juridique).
- Source retenue : **DATAtourisme** (open data, Licence Ouverte, pas de scraping).
- Compte diffuseur + application `cobroc` + flux `cobroc-flux` créés.
  FLOW_ID = `fc4aa6312d18f42f438d0780a99e97ac`.
- Script : `server/scripts/datatourisme_brocantes.py` (stdlib + dotenv ; pas de
  requests/bs4/pandas). Lit `.env`, télécharge le ZIP, parse, filtre brocantes,
  trie par date. Compile OK, erreurs gérées (503/404/401).
- Doc complète : **`datatourisme.md`** (racine).
- **Statut** : test = HTTP 503 persistant. Cause identifiée le 23/06 via `--debug-http` :
  génération du flux **non programmée / désactivée pour inactivité** (config FLOW_ID+clé
  OK). → action sur le portail diffuseur (voir « À FAIRE EN PRIORITÉ »).
- Ajout le 23/06 du flag `--debug-http` (affiche en-têtes + corps des réponses HTTP en erreur).

## ❓ QUESTION EN SUSPENS
- **Zone géographique du flux** DATAtourisme : pas confirmée (Île-de-France ?
  départements précis ?). À préciser dans `datatourisme.md` une fois connue.

## 🧹 À NETTOYER
- `server/scripts/videgrenier.py` : brouillon de scraping vide-greniers.org,
  **inutilisable et abandonné** (robots.txt). À **supprimer** ou neutraliser.
  (Apparaît en `AM` dans git — semble partiellement indexé.)

## 📦 ÉTAT GIT AU 2026-06-18 (branche `main`, rien de committé cette session)
```
 M lib/historibroc.dart            (modif antérieure à la session)
 M server/db/historibroc.db        (modif antérieure à la session)
 M server/.env.example             (ajout vars DATATOURISME_*)
 M server/CLAUDE.md                (doc édition web)
 M server/static/index.html        (feature édition visites)
AM server/scripts/videgrenier.py   (à supprimer/neutraliser)
?? datatourisme.md                 (nouvelle doc)
?? server/scripts/datatourisme_brocantes.py (nouveau script)
?? MAJDB.md, android/              (antérieurs, non liés)
```
Aucun commit n'a été fait — à décider à la reprise quoi committer.
