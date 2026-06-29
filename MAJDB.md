# MAJDB — Mise à jour de listHistoric depuis historibroc.db

## Principe

`lib/historibroc.dart` contient la liste statique `listHistoric` compilée dans
le binaire. La source de vérité est désormais `db/historibroc.db` (table
`historic`). Pour mettre à jour la liste, on modifie la DB puis on régénère le
fichier dart avec le script ci-dessous.

## Prérequis

- Python 3 (disponible en standard sur macOS)
- `sqlite3` (inclus dans la stdlib Python)
- Flutter installé (pour le `flutter analyze` final)

## Schéma de la table `historic`

```sql
CREATE TABLE IF NOT EXISTS historic (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  hist_name        TEXT    NOT NULL,          -- "PML" ou "FRA"
  hist_date        TEXT    NOT NULL,          -- format ISO : YYYY-MM-DD
  hist_good        INTEGER NOT NULL DEFAULT 0,
  hist_ville       TEXT    NOT NULL,
  hist_code_postal INTEGER NOT NULL DEFAULT 0,
  hist_adresse     TEXT    NOT NULL DEFAULT '',
  hist_nb_expo     INTEGER NOT NULL DEFAULT 0,
  hist_pml_dep     INTEGER NOT NULL DEFAULT 0,
  hist_fra_dep     INTEGER NOT NULL DEFAULT 0,
  hist_maison_dep  INTEGER NOT NULL DEFAULT 0,
  hist_avis        TEXT    NOT NULL DEFAULT '',
  hist_detail      TEXT    NOT NULL DEFAULT '',
  validated        INTEGER NOT NULL DEFAULT 0, -- mettre à 1 pour inclure
  agent_notes      TEXT    NOT NULL DEFAULT '',
  created_at       TEXT    NOT NULL DEFAULT (datetime('now'))
);
```

> Seules les lignes avec `validated = 1` sont exportées.  
> Les dates doivent être en format ISO (`YYYY-MM-DD`), pas en format français.

## Script de régénération

Copier-coller dans un terminal depuis la racine du projet :

```python
python3 << 'PYEOF'
import sqlite3

DB_PATH = "db/historibroc.db"
DART_PATH = "lib/historibroc.dart"

def iso_to_french(d):
    parts = d.split("-")
    if len(parts) == 3:
        return f"{parts[2]}/{parts[1]}/{parts[0]}"
    return d

con = sqlite3.connect(DB_PATH)
cur = con.cursor()
cur.execute("""
    SELECT hist_name, hist_date, hist_good, hist_ville, hist_code_postal,
           hist_adresse, hist_nb_expo, hist_pml_dep, hist_fra_dep,
           hist_maison_dep, hist_avis, hist_detail
    FROM historic
    WHERE validated = 1
    ORDER BY id
""")
rows = cur.fetchall()
con.close()

# Lire le header actuel (lignes 1 à 68 = avant "final listHistoric = [")
with open(DART_PATH, encoding='utf-8') as f:
    existing = f.readlines()
header_lines = []
for line in existing:
    if line.startswith('final listHistoric'):
        break
    header_lines.append(line)

# Mettre à jour la date dans l'en-tête (ligne 2)
from datetime import datetime
ts = datetime.now().strftime('%y%m%d%H%M')
header_lines[1] = f'// Modified: {ts}\n'
header_lines[3] = f'// CHANGEMENTS: (1) listHistoric régénérée depuis historibroc.db ({len(rows)} entrées), ligne 70\n'

parts = [''.join(header_lines), 'final listHistoric = [\n']
for row in rows:
    name, date_iso, good, ville, cp, adresse, nb_expo, pml_dep, fra_dep, maison_dep, avis, detail = row
    date_fr = iso_to_french(date_iso)
    entry = (
        f'  Historic("{name}", "{date_fr}", {good}, "{ville}", {cp}, '
        f'"{adresse}", {nb_expo}, {pml_dep}, {fra_dep}, {maison_dep}, '
        f'"{avis}", "{detail}"),\n'
    )
    parts.append(entry)
parts.append('];\n')

with open(DART_PATH, 'w', encoding='utf-8') as f:
    f.writelines(parts)

print(f"OK — {len(rows)} entrées écrites dans {DART_PATH}")
PYEOF
```

Puis valider :

```bash
flutter analyze lib/historibroc.dart
```

## Procédure complète de MAJ

1. **Backup** (par sécurité) :
   ```bash
   cp lib/historibroc.dart lib/historibroc.dart.bak$(date +%y%m%d)
   ```

2. **Modifier la DB** avec DB Browser for SQLite ou en ligne de commande :
   ```bash
   sqlite3 db/historibroc.db
   ```
   Exemples d'insertions :
   ```sql
   INSERT INTO historic
     (hist_name, hist_date, hist_good, hist_ville, hist_code_postal,
      hist_adresse, hist_nb_expo, hist_pml_dep, hist_fra_dep, hist_maison_dep,
      hist_avis, hist_detail, validated)
   VALUES
     ('PML', '2026-06-07', 0, 'PONTOISE', 95300, 'Centre Ville',
      150, 12, 0, 0, 'Brocante sympa', 'Livres=3€', 1);
   ```

3. **Régénérer** le dart (script ci-dessus).

4. **Valider** : `flutter analyze lib/historibroc.dart` → doit afficher `No issues found`.

5. **Commiter** les deux fichiers ensemble :
   ```bash
   git add db/historibroc.db lib/historibroc.dart
   git commit -m "feat: MAJ historic — XX nouvelles entrées (DATE)"
   ```

## Points d'attention

- Les guillemets `"` dans `hist_avis` / `hist_detail` doivent être stockés
  échappés dans la DB sous la forme `\"` (backslash + guillemet), exactement
  comme dans un littéral de chaîne Dart.
- Le champ `hist_date` doit impérativement être en format ISO `YYYY-MM-DD`.
  Le script convertit automatiquement en `DD/MM/YYYY` pour le dart.
- Ne pas modifier `validated` à `0` sur des entrées existantes sans raison :
  elles disparaîtraient silencieusement de la liste compilée.
- Le fichier backup `*.bak*` n'est pas traqué par git (`.gitignore` conseillé).
