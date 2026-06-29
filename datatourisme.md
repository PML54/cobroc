# DATAtourisme — liste brocantes/vide-greniers (complément à brocabrac)

> Doc de travail — créée le 2026-06-18. Résume pourquoi et comment on récupère
> une liste **date + ville** de brocantes via l'open data **DATAtourisme**, pour
> combler les lieux absents de brocabrac.fr. **Usage personnel, non commercial.**

## 1. Le besoin

brocabrac.fr (source principale de cobroc) **manque certains lieux**. Idée : un
petit script qui sort une liste `date + ville` de brocantes/vide-greniers pour
compléter, sans saisie manuelle.

## 2. Pourquoi PAS vide-greniers.org

Premier réflexe : scraper `vide-greniers.org`. **Abandonné**, pour deux raisons :

- **`robots.txt` interdit le scraping** : `User-agent: * → Disallow: /` (accès
  réservé aux moteurs nommés : Google, Bing…). Un script perso tombe sous ce
  `Disallow`. Le `CLAUDE.md` du projet interdit explicitement d'ignorer le
  `robots.txt`.
- **Exposition juridique** : ouvrir une 2ᵉ source de scraping élargit la question
  non tranchée des droits sur les données (CGU + droit *sui generis* sur les bases),
  déjà bloquante pour la publication de cobroc.

> Recherche faite : pas de flux RSS/iCal ni d'API publique d'événements côté
> vide-greniers.org / réseau agenda.org (seul le site vitrine `info.agenda.org`
> est ouvert, mais sans données d'événements).

## 3. La source retenue : DATAtourisme

**DATAtourisme** = plateforme **nationale officielle** d'open data touristique.
Les offices de tourisme y publient leurs événements (dont brocantes/vide-greniers)
sous **Licence Ouverte** (réutilisation autorisée).

- **Ce n'est pas du scraping** : on récupère un **flux** que DATAtourisme met à
  disposition pour ça → aucun `robots.txt` enfreint, pas de zone grise juridique.
- Données riches en **JSON-LD**, filtrables par **type d'événement** + **zone**.

### Compte / application / flux (espace diffuseur)

Portail : <https://diffuseur.datatourisme.fr/>

1. **Compte** diffuseur (réutilisateur) créé, e-mail validé.
2. **Application** : `cobroc` → fournit une **clé d'application** (secret).
3. **Flux** : `cobroc-flux`, configuré avec deux critères :
   - **Type** = « Fête et manifestation » (`FeteEtManifestation`) — branche
     contenant les brocantes/vide-greniers (filtrage fin fait ensuite par le script).
   - **Zone géographique** = (à ajuster : Île-de-France / départements voulus).
   - **Format** = JSON-LD (par défaut).
4. **URL de webservice** (renvoie un ZIP de JSON-LD) :
   ```
   https://diffuseur.datatourisme.fr/webservice/<FLOW_ID>/<APP_KEY>
   ```
   FLOW_ID actuel : `fc4aa6312d18f42f438d0780a99e97ac`.

> ⚠️ Le flux est **généré la nuit** suivant sa création/modification. Avant ça,
> le webservice renvoie **HTTP 503** (= existe mais pas encore construit).

## 4. Configuration (secrets)

Variables dans **`server/.env`** (gitignoré — jamais versionné) :

```
DATATOURISME_FLOW_ID=fc4aa6312d18f42f438d0780a99e97ac
DATATOURISME_APP_KEY=<clé de l'application cobroc>   # SECRET
```

Documentées (placeholders) dans `server/.env.example`. La clé reste **locale** ;
le script la lit via `python-dotenv`, elle n'apparaît ni dans le chat ni dans Git.

## 5. Le script

**`server/scripts/datatourisme_brocantes.py`** — stdlib uniquement
(`urllib` / `zipfile` / `json`) + `python-dotenv` (déjà installé). Pas de
`requests` / `bs4` / `pandas`.

Ce qu'il fait : lit `FLOW_ID`+`APP_KEY` depuis `.env` → télécharge le ZIP du flux
→ parse les JSON-LD → repère les brocantes/vide-greniers parmi les « Fête et
manifestation » (mots-clés : *brocante, vide-grenier, puces, déballage…*) →
extrait **date + ville (+ CP + titre)** → trie par date → affiche ou exporte CSV.

### Usage (depuis `server/`)

```bash
.venv/bin/python scripts/datatourisme_brocantes.py            # brocantes à venir
.venv/bin/python scripts/datatourisme_brocantes.py --days 30  # 30 prochains jours
.venv/bin/python scripts/datatourisme_brocantes.py --all      # toutes dates
.venv/bin/python scripts/datatourisme_brocantes.py --csv brocantes.csv
.venv/bin/python scripts/datatourisme_brocantes.py --inspect 2 # debug structure JSON-LD
```

### Gestion d'erreurs

| Code | Message | Sens |
|------|---------|------|
| 503  | « flux pas encore généré » | Attendre la génération de nuit, réessayer demain |
| 404  | « flux introuvable »       | Vérifier FLOW_ID / APP_KEY |
| 401/403 | « accès refusé »        | Clé d'application invalide |

## 6. Statut au 2026-06-18

- Script écrit, compile, erreurs gérées proprement. Clé + FLOW_ID en place.
- Test de téléchargement → **HTTP 503** : flux pas encore généré (config OK, le
  503 ≠ 401/403/404 confirme que flux + clé sont reconnus).

## 7. Reste à faire

1. **Demain** (flux généré) : lancer `--inspect 2` et **vérifier la vraie
   structure JSON-LD** (noms réels des propriétés date / commune / CP). Ajuster
   l'extraction du script si besoin (`_dates`, `_ville_cp`, `_is_brocante`).
2. Une fois validé sur données réelles : **documenter le script dans
   `server/CLAUDE.md`** (liste des scripts).
3. Option : **croiser** la liste DATAtourisme avec brocabrac pour ne montrer que
   les **lieux manquants**.

> Rappel périmètre : ce flux est un **outil perso de repérage**. Il n'alimente pas
> automatiquement la base `historibroc.db` (qui reste la source de vérité, saisie
> via le serveur + validation agent).
