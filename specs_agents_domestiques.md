# Spécifications — Agents domestiques

> Document de référence. Récapitule les décisions prises et sert de cahier des
> charges. À amender au fil du développement.
> Convention : termes techniques IA/ML en anglais (tool-calling, prompt, token,
> embedding, inference, MCP server, structured output, RAG…).

---

## 1. Vue d'ensemble

Objectif : mettre en place, à des fins de formation, des **agents domestiques**
personnels tournant sur 2 Macs, capables d'interagir avec des comptes et des
services (mail, agenda, Google Sheets, sites fr) via du **tool-calling**.

Décisions transverses :

| Sujet | Choix retenu |
|---|---|
| Langage | **Python** |
| LLM | **API Anthropic** (modèle `claude-opus-4-8` ; `claude-sonnet-4-6` pour le volume) |
| Protocole d'outils | **MCP** (Model Context Protocol) comme socle réutilisable |
| Parc | **2 Macs**, code partagé par git ; credentials/token locaux à chaque machine |
| Premier domaine | **Brocantes** (et non les comptes mail/agenda, repoussés) |

Principe d'architecture directeur : **découpler la logique métier de la
persistance et de la couche d'exposition.** Une logique écrite une fois
(`models.py` + `*_tools.py`), exposée de plusieurs façons (agent loop CLI,
MCP server) sans duplication.

---

## 2. Agent prioritaire — CR de brocante (cobrac-cr)

### 2.1 Besoin

Enrichir les comptes-rendus de brocante :
- **saisie guidée** par un agent conversationnel qui pose des questions standards
  puis recueille un commentaire libre, et écrit le résultat dans une Google Sheet ;
- **analyse / synthèse** des CR passés.

Workflow existant : app **cobroc** (Flutter) analyse Brocabrac → repérage des
brocantes ; en fin de week-end, saisie d'un CR par brocante chinée ; stockage dans
une Google AppSheet (donc Google Sheet sous-jacente).

### 2.2 Modèle de données (validé)

Une ligne = un CR d'un chineur sur une brocante. Colonnes A→L :

| Col | Champ | Sémantique | Format |
|---|---|---|---|
| A | CHINEUR | Auteur du CR : `PML` (Paul) / `FRA` (sa femme) | enum |
| B | DATE | Date de la brocante | JJ/MM/AAAA |
| C | Qual | Note d'instinct qualité, 0–3 (0 mauvais, 3 très bon) | int, optionnel |
| D | VILLE | Commune | texte |
| E | CP | Code postal (garde le 0) | texte |
| F | LIEU-dit | Lieu précis | texte |
| G | Expo | Nombre d'exposants | int |
| H | PML | € achats **revente** de Paul | montant |
| I | FRA | € achats **revente** de sa femme | montant |
| J | MAI | € achats pour la **maison** (perso/commun) | montant |
| K | Commentaires | Texte libre | texte long |
| L | Détails | Trouvailles + prix, format `objet=prix€+…` | texte long |

Points de vigilance sémantiques :
- `PML`/`FRA` désignent TOUJOURS une personne (Paul / sa femme), mais avec un rôle
  différent selon la colonne : col A = qui rédige le CR ; col H/I = qui a dépensé
  pour la revente. Col J (MAI) = dépense maison.
- Modèle métier interne découplé : noms non ambigus (`depense_revente_pml`,
  `depense_revente_fra`, `depense_maison`), puis `flatten_to_row()` aplatit vers
  A→L. La Sheet existante n'est pas modifiée (AppSheet continue de tourner).

### 2.3 Déroulé de l'interview

Infos brocante (date, ville, CP, lieu, nb exposants, qualité) souvent déjà
connues (Cobrac) → l'agent CONFIRME plutôt que d'interroger ; sinon il demande.
Puis, une question à la fois :

1. Heure d'arrivée + parking/accès
2. Dépenses : revente Paul, revente FRA, maison (€)
3. Trouvailles + prix
4. On y retourne l'an prochain ?
5. Commentaire libre

Règles : relance si réponse vague ; accepte « sans avis » pour un champ optionnel ;
n'invente jamais de valeur ; **récapitule + validation explicite avant écriture** ;
après écriture, propose d'enchaîner le CR de l'autre chineur sur la même brocante.

### 2.4 Tools

| Tool | Type | Rôle |
|---|---|---|
| `sheet_append_cr` | write | Ajoute une ligne de CR (refuse si validation échoue) |
| `sheet_read_rows` | read | Lit les N dernières lignes |
| `sheet_list_brocantes` | read | Liste filtrable (ville, chineur) pour synthèse |

### 2.5 Accès aux données

- **Google Sheets API**, OAuth desktop, scope `spreadsheets`.
- `valueInputOption=USER_ENTERED` pour que dates et montants soient interprétés
  comme une saisie (cohérence AppSheet).
- Écriture limitée aux colonnes A→L ; ne pas ajouter de colonne ni toucher l'en-tête.

### 2.6 Modes d'utilisation (les deux)

**Mode A — Claude Code / Claude Desktop (langage naturel)** via un **MCP server**
(`cobrac_mcp_server.py`, FastMCP, transport stdio) qui réexpose les 3 tools.
Enregistrement : `claude mcp add cobrac -- <python> <chemin/cobrac_mcp_server.py>`.

**Mode B — commande système `cobrac`** : `agent.py` transformé en entry point
(`pyproject.toml`), lance l'interview guidée scriptée dans le terminal.

Les deux modes appellent la MÊME logique (`models.py` + `sheet_tools.py`).

### 2.7 Contraintes techniques notées

- **stdio** : interdiction d'écrire sur stdout (corrompt le JSON-RPC) → logs sur
  stderr uniquement.
- **OAuth** : `token.json` doit exister AVANT de lancer le MCP server
  (script `auth_setup.py` one-shot) pour éviter l'ouverture d'un navigateur.
- credentials.json / token.json : locaux à chaque Mac, jamais versionnés.

---

## 3. Agents repoussés (backlog)

### 3.1 Mail / Agenda (Google)

Première idée, mise de côté au profit des brocantes. Spécifié partiellement :
- Tools `gmail_search`, `calendar_upcoming` (lecture seule pour démarrer).
- Même socle OAuth desktop que la Sheet (scopes `gmail.readonly`,
  `calendar.readonly`), extensible à l'écriture (envoi, création d'événement).
- Réutilisable tel quel comme MCP server le moment venu.

### 3.2 Sites fr sans API (navigateur)

Repoussé. Monde différent : pilotage de navigateur (Playwright + browser-use /
Stagehand), avec contraintes anti-bot, 2FA, et questions CGU. À traiter seulement
quand un besoin concret le justifie.

---

## 4. Architecture cible commune

```
        logique métier (écrite UNE fois)
        ┌───────────────────────────────┐
        │ models.py     (objets + flatten)│
        │ *_tools.py    (persistance+tools)│
        └───────┬───────────────┬─────────┘
                │               │
   MCP server (stdio)      agent loop CLI
   cobrac_mcp_server.py    agent.py / cmd `cobrac`
                │               │
        Claude Code /        terminal interactif
        Claude Desktop       (interview scriptée)
```

Tout nouvel agent suit le même patron : un module métier découplé, exposé via
MCP server (réutilisable partout) et/ou via un agent loop dédié.

---

## 5. Roadmap

| Étape | État |
|---|---|
| Agent CR brocante — code (models, tools, agent, MCP server) | **fait, compilé/testé** |
| Brancher la vraie Sheet (ID, onglet) + OAuth | à faire (côté Paul) |
| Tester écriture d'une ligne réelle | à faire |
| Enregistrer le MCP server dans Claude Code sur les 2 Macs | à faire |
| Brancher Cobrac en amont (JSON → pré-remplissage du CR) | à faire (`parse_cobrac_json` prêt, aligner les clés) |
| 4e tool `cobrac_scan_brocabrac` dans le MCP server | idée |
| Agents mail/agenda | backlog |
| Agents navigateur (sites fr) | backlog |

---

## 6. Points ouverts / à trancher

- Format réel du structured output de Cobrac (pour aligner `parse_cobrac_json`).
- Colonne clé technique cachée éventuelle dans la Sheet AppSheet (décalage A→L ?).
- Une session d'interview = 1 ligne (chineur), avec enchaînement proposé pour le 2e.
- Détails légaux Brocabrac à préciser (impact sur publication de cobroc, pas sur
  l'agent CR lui-même).
