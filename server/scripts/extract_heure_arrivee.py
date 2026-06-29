"""
scripts/extract_heure_arrivee.py
Détecte l'heure d'arrivée dans hist_avis et peuple heure_arrivee si vide.

Patterns reconnus (insensible à la casse) :
  "arrivée vers 8h30", "arrivé à 9h", "vers 10h00", "à 8:30", "9h30", "8h"...

Usage :
  python3 scripts/extract_heure_arrivee.py           # dry-run : affiche sans modifier
  python3 scripts/extract_heure_arrivee.py --apply   # applique les mises à jour
"""

import re
import sqlite3
import sys
from pathlib import Path

DB_PATH = Path(__file__).parent.parent / "db" / "historibroc.db"

# Mots-clés déclencheurs (doivent précéder l'heure, séparés par espaces/ponctuation)
KEYWORDS = r'(?:arriv[eéè][e]?s?|faite?s?)'

# Patterns : mot-clé + éventuels mots intermédiaires (vers, à, le, …) + heure
# Groupe "h" = heure, groupe "m" = minutes (optionnel)
PATTERNS = [
    # "arrivée vers 8h30", "arrivé à 8h00"
    rf'{KEYWORDS}[^0-9\n]{{0,20}}?(?P<h>\d{{1,2}})h(?P<m>\d{{2}})\b',
    # "arrivée vers 8:30"
    rf'{KEYWORDS}[^0-9\n]{{0,20}}?(?P<h>\d{{1,2}}):(?P<m>\d{{2}})\b',
    # "arrivée vers 8h" (sans minutes)
    rf'{KEYWORDS}[^0-9\n]{{0,20}}?(?P<h>\d{{1,2}})h\b(?!\d)',
]

def extract_time(text: str) -> str | None:
    """Retourne 'HH:MM' si une heure précédée d'un mot-clé est détectée, None sinon."""
    if not text:
        return None
    t = text.lower()
    for pat in PATTERNS:
        m = re.search(pat, t)
        if m:
            heure   = int(m.group('h'))
            minutes = int(m.group('m')) if 'm' in m.groupdict() and m.group('m') else 0
            if 0 <= heure <= 23 and 0 <= minutes <= 59:
                return f"{heure:02d}:{minutes:02d}"
    return None


def main(apply: bool = False):
    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row

    rows = con.execute(
        "SELECT id, hist_ville, hist_date, hist_avis FROM historic "
        "WHERE (heure_arrivee IS NULL OR heure_arrivee = '') AND hist_avis != '' "
        "ORDER BY hist_date DESC"
    ).fetchall()

    updates = []
    for r in rows:
        t = extract_time(r["hist_avis"])
        if t:
            updates.append((t, r["id"], r["hist_ville"], r["hist_date"], r["hist_avis"]))

    print(f"{len(rows)} records sans heure_arrivee, {len(updates)} heure(s) détectée(s).\n")

    for heure, rid, ville, date, avis in updates:
        extrait = avis[:80].replace('\n', ' ')
        print(f"  #{rid:4d}  {date}  {ville:<20s}  → {heure}   « {extrait}… »")

    if not updates:
        print("Rien à faire.")
        con.close()
        return

    if not apply:
        print("\n[dry-run] Relancez avec --apply pour appliquer.")
    else:
        con.executemany(
            "UPDATE historic SET heure_arrivee = ? WHERE id = ?",
            [(h, rid) for h, rid, *_ in updates],
        )
        con.commit()
        print(f"\n✓ {len(updates)} enregistrement(s) mis à jour.")

    con.close()


if __name__ == "__main__":
    main(apply="--apply" in sys.argv)
