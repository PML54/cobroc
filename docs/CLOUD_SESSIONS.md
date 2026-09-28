# Sessions Claude Code cloud — cobroc

But : exécuter cobroc en **session cloud Claude Code** (claude.ai/code) pour
`flutter analyze` / `flutter test` **et** l'outillage `server/` Python. Le cloud
sert à **éditer / analyser / tester**, PAS à lancer l'app (pas d'appareil ni
d'émulateur) ni à valider le ressenti d'un geste : ça reste sur le Mac.

Le montage tient en **deux pièces** qui se répartissent le travail comme le
recommande la doc Claude Code (setup script = provisionner la VM ; SessionStart
hook = résoudre les dépendances du projet).

## Pièce A — Setup script (config de l'*environment*, UI web)

À coller dans le champ **Setup script** de l'environnement cloud
(claude.ai/code → environnement → réglages). Il n'est **pas** versionné : il vit
dans la config de l'environnement. Il installe ce qui n'est pas pré-installé
(Flutter) et prépare le venv Python (le runtime Python, lui, est déjà présent).

```bash
#!/bin/bash
set -euo pipefail

# --- Flutter (dernière stable) ---
FLUTTER_DIR="$HOME/flutter"
if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

# --- venv Python pour server/ : HORS du repo ---
# Le repo est recloné à neuf chaque session ; un venv dans server/ serait perdu.
# Placé dans $HOME, il entre dans le snapshot de cache et survit.
VENV="$HOME/.venv-cobroc"
[ -d "$VENV" ] || python3 -m venv "$VENV"
"$VENV/bin/pip" install -q --upgrade pip
# pip install des deps ICI seulement si le repo est déjà cloné à ce stade ;
# sinon le SessionStart hook s'en charge (voir Pièce B).
[ -f server/requirements.txt ] && "$VENV/bin/pip" install -q -r server/requirements.txt || true

# PATH pour les shells de la session (idempotent) : chaque commande Bash de
# Claude source ~/.bashrc, donc flutter/dart et le venv y deviennent visibles.
LINE='export PATH="$HOME/flutter/bin:$HOME/.venv-cobroc/bin:$PATH"'
grep -qxF "$LINE" "$HOME/.bashrc" 2>/dev/null || echo "$LINE" >> "$HOME/.bashrc"
export PATH="$FLUTTER_DIR/bin:$VENV/bin:$PATH"

flutter config --no-analytics >/dev/null 2>&1 || true
flutter --version
```

## Pièce B — SessionStart hook (`.claude/settings.json`, versionné)

Déjà en place dans ce dépôt. Deux commandes s'y exécutent au démarrage :

1. **Flutter** (préexistant) : si `flutter` est sur le PATH → `flutter pub get`
   quand `.dart_tool` manque, puis rappel « lancer analyze/test avant de
   présenter un diff ». Sinon, avertissement : flutter absent = installer via la
   Pièce A (le PATH d'un sous-process du hook ne remonte pas ; c'est `.bashrc`,
   écrit par le setup script, qui rend flutter persistant).
2. **server/ Python** (ajout) : **uniquement en cloud** (garde
   `CLAUDE_CODE_REMOTE_SESSION_ID`, pour ne pas polluer le Mac). Crée le venv
   `$HOME/.venv-cobroc` si absent, `pip install -r server/requirements.txt`,
   puis signale que les scripts se lancent via `$HOME/.venv-cobroc/bin/python`
   (le venv n'est PAS sur le PATH par défaut dans le hook).

## Réseau — laisser **Trusted** (ne pas passer en Custom)

Le niveau **Trusted** (défaut) autorise les package registries + GitHub → le
clone Flutter et `pip`/pub.dev passent. Il **n'inclut pas** `brocabrac.fr` ni les
sources datatourisme : elles sont **injoignables par construction**. C'est un
alignement direct avec le gel légal (cf. `CLAUDE.md`) : ne PAS basculer en
**Custom** pour rendre ces domaines joignables tant que la question des droits
n'est pas tranchée.

## Secrets — validateur `server/agent/validator.py`

- La majorité de l'outillage (`export_dart.py`, migrations) : **aucun secret,
  aucun réseau** hors PyPI. `server/db/historibroc.db` est versionnée → présente.
- Le validateur appelle l'**API Anthropic** (clé dans `server/.env`, gitignoré).
  En cloud (Pro/Max) : fournir la clé en **API credential** sur l'environnement,
  hôte `api.anthropic.com` — l'agent proxy l'attache après la sortie de la VM, la
  session ne la voit jamais. **Jamais** en variable d'environnement (lisible par
  quiconque utilise l'environnement). **Jamais** committer `server/.env`.

## Point fragile à connaître — couplage de chemins

Pièce A et Pièce B partagent en dur `$HOME/flutter` et `$HOME/.venv-cobroc`. Si
l'un de ces chemins change dans le setup script, **mettre à jour le hook en
même temps**. C'est le seul couplage implicite du montage.

## Limites assumées

- **Cache ~5 min** : le setup script n'est mis en cache (snapshot réutilisé
  ~7 jours) que s'il finit sous ~5 min. Clone Flutter + Dart SDK est le facteur
  limitant ; s'il dépasse, ça marche mais le script se rejoue chaque session
  (démarrage lent). Vérifier au premier démarrage (`check-tools`, chrono).
- **Pas d'exécution d'app** : ni rendu UI ni geste ; uniquement analyze/test et
  scripts Python.

## Mémo — cycle terminal ↔ cloud (démarche sûre)

<!-- Ajouté 2026-09-28. Consigne l'enchaînement `--cloud` → relecture →
     `--teleport`, durci par la leçon de l'incident du 27/09 (stash du teleport). -->

Deux commandes, **sens opposés** :

- `claude --cloud "<tâche>"` — terminal → cloud : **crée** une nouvelle session,
  la VM **clone le remote GitHub** à la branche courante (PAS la copie locale).
- `claude --teleport <session-id>` — cloud → terminal : **rapatrie** la branche
  poussée par la session + l'historique de conversation, pour continuer/vérifier
  en local (indispensable pour `flutter build`, que le cloud ne peut pas faire).

### Trois règles qui rendent le cycle sûr

1. **C'est le `push` qui porte, pas le `commit`.** `--cloud` clone le *remote* :
   un commit non poussé est invisible pour la VM. Vérifier `git status` →
   *up to date with origin* AVANT de lancer, ne pas supposer.
2. **`--teleport` exige un working dir *propre* — au moment du teleport.** Sinon
   il propose de **stash** : c'est exactement ce qui a fait tomber
   `historibroc.db` le 27/09. Donc `git status` **vide** avant tout teleport
   (committer ou stasher volontairement le travail local d'abord).
3. **Laisser la session finir, puis relire.** Entre `--cloud` et `--teleport` :
   suivre + relire le diff/les tests sur `claude.ai/code`, teleporter seulement
   une fois la session terminée (sinon on rapatrie une branche incomplète).

### Séquence de référence

```bash
cd <racine du repo>
git switch -c ma-tache            # branche dédiée (propre ; évite de polluer main)
git add -A && git commit -m "wip: point de départ"
git push -u origin ma-tache       # ← étape critique : sans push, le cloud ne voit rien
claude --cloud "Ma tâche..."      # noter l'ID de session affiché
#   → suivi + relecture sur claude.ai/code, ON LAISSE FINIR
git status                        # ← DOIT être vide avant teleport
claude --teleport session_XXXX    # rapatrie la branche + l'historique
```

Notes : `--cloud` = **un seul repo** à la fois. `--teleport` doit se lancer
depuis un checkout du **même** repo (pas un fork). Après teleport, le lien est
coupé : la copie locale n'alimente plus la session cloud (pour re-piloter depuis
le mobile, lancer `/remote-control`). Ne pas confondre `--teleport` (session
cloud + branche) avec `--resume` (historique purement local).

### Constat empirique 2026-09-28 — ce repo part en *bundle*, pas en clone

Vérifié en session : `claude --cloud` depuis ce dépôt crée la VM par
`git clone /home/user/.seed.bundle` (bundle local téléversé), **pas** par un
clone réseau de `origin`. Conséquences observées :

- `git remote -v` **vide** dans la VM, aucune branche `remotes/origin/*` ;
- historique **complet** quand même (bundle = tout le repo, pas un shallow) ;
- **impossible de `git push`** tel quel : il faut d'abord
  `git remote add origin https://github.com/PML54/cobroc.git` puis push
  (le token `/web-setup` a les droits `repo`), sinon le travail non poussé
  **meurt avec la VM éphémère** (vécu le 27/09 et le 28/09).

Cause probable (à confirmer si on y revient) : la connexion claude.ai ↔ GitHub
passe par **`/web-setup`** (token `gh`), pour laquelle le provisionnement
**bundle par défaut**. Installer l'**App GitHub Claude** *sur le repo* est
nécessaire mais **pas suffisant** — testé le 28/09, ça bundle toujours. Le mode
clone exigerait de connecter claude.ai **via l'App GitHub** (onboarding web), pas
via `/web-setup`. À NE PAS confondre avec la policy réseau : le bundling est une
décision **côté client** (avant démarrage VM), sans rapport avec **Trusted** qui
ne bloque que `brocabrac.fr`, pas `github.com`.

**Règle pratique tant que c'est en mode bundle** : avant de fermer une session
cloud, `git remote add origin <url>` + `git push -u origin <branche>` — ou
récupérer le travail autrement — sinon perte. Et : pour cobroc, le cloud reste un
**mauvais outil** (gel légal du scraping, Flutter absent de la VM, friction
bundle) → privilégier le travail **local**.
