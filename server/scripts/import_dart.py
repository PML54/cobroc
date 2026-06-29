#!/usr/bin/env python3
"""
scripts/import_dart.py
Migration one-shot : parse historibroc.dart → SQLite historibroc.db
Usage : python scripts/import_dart.py [--dart PATH] [--db PATH]
"""

import re
import sqlite3
import argparse
from pathlib import Path

DEFAULT_DART = Path(__file__).parent.parent.parent / "lib/historibroc.dart"
DEFAULT_DB   = Path(__file__).parent.parent / "db/historibroc.db"
SCHEMA       = Path(__file__).parent.parent / "db/schema.sql"

# Regex pour capturer Historic("...", "...", N, "...", N, "...", N, N, N, N, "...", "...")
# Les chaînes peuvent contenir des guillemets échappés, des virgules, des retours à la ligne.
_ENTRY_RE = re.compile(
    r'Historic\s*\(\s*'
    r'"((?:[^"\\]|\\.)*)"\s*,\s*'   # histName
    r'"((?:[^"\\]|\\.)*)"\s*,\s*'   # histDate
    r'(\d+)\s*,\s*'                  # histGood
    r'"((?:[^"\\]|\\.)*)"\s*,\s*'   # histVille
    r'(\d+)\s*,\s*'                  # histCodePostal
    r'"((?:[^"\\]|\\.)*)"\s*,\s*'   # histAdresse
    r'(\d+)\s*,\s*'                  # histNbExpo
    r'(\d+)\s*,\s*'                  # histPmlDep
    r'(\d+)\s*,\s*'                  # histFraDep
    r'(\d+)\s*,\s*'                  # histMaisonDep
    r'"((?:[^"\\]|\\.)*)"\s*,\s*'   # histAvis
    r'"((?:[^"\\]|\\.)*)"'           # histDetail
    r'\s*\)',
    re.DOTALL,
)


def _to_iso(date_str: str) -> str:
    """Convertit JJ/MM/AAAA → AAAA-MM-JJ. Laisse intact si déjà ISO."""
    if len(date_str) == 10 and date_str[2] == "/" and date_str[5] == "/":
        return date_str[6:10] + "-" + date_str[3:5] + "-" + date_str[0:2]
    return date_str


def parse_dart(dart_path: Path) -> list[dict]:
    text = dart_path.read_text(encoding="utf-8")
    entries = []
    for m in _ENTRY_RE.finditer(text):
        entries.append({
            "hist_name":        m.group(1),
            "hist_date":        _to_iso(m.group(2)),
            "hist_good":        int(m.group(3)),
            "hist_ville":       m.group(4),
            "hist_code_postal": int(m.group(5)),
            "hist_adresse":     m.group(6),
            "hist_nb_expo":     int(m.group(7)),
            "hist_pml_dep":     int(m.group(8)),
            "hist_fra_dep":     int(m.group(9)),
            "hist_maison_dep":  int(m.group(10)),
            "hist_avis":        m.group(11),
            "hist_detail":      m.group(12),
            "validated":        1,   # données existantes déjà validées
            "agent_notes":      "import initial depuis historibroc.dart",
        })
    return entries


def init_db(db_path: Path) -> sqlite3.Connection:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect(db_path)
    con.executescript(SCHEMA.read_text())
    con.commit()
    return con


def insert_entries(con: sqlite3.Connection, entries: list[dict]) -> int:
    sql = """
        INSERT INTO historic
          (hist_name, hist_date, hist_good, hist_ville, hist_code_postal,
           hist_adresse, hist_nb_expo, hist_pml_dep, hist_fra_dep,
           hist_maison_dep, hist_avis, hist_detail, validated, agent_notes)
        VALUES
          (:hist_name, :hist_date, :hist_good, :hist_ville, :hist_code_postal,
           :hist_adresse, :hist_nb_expo, :hist_pml_dep, :hist_fra_dep,
           :hist_maison_dep, :hist_avis, :hist_detail, :validated, :agent_notes)
    """
    con.executemany(sql, entries)
    con.commit()
    return len(entries)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dart", default=str(DEFAULT_DART))
    ap.add_argument("--db",   default=str(DEFAULT_DB))
    ap.add_argument("--force", action="store_true", help="Vide la table avant import")
    args = ap.parse_args()

    dart_path = Path(args.dart)
    db_path   = Path(args.db)

    if not dart_path.exists():
        print(f"[ERREUR] Fichier Dart introuvable : {dart_path}")
        return

    print(f"Lecture de {dart_path} …")
    entries = parse_dart(dart_path)
    print(f"  {len(entries)} entrées parsées")

    con = init_db(db_path)

    if args.force:
        con.execute("DELETE FROM historic")
        con.commit()
        print("  Table vidée (--force)")

    existing = con.execute("SELECT COUNT(*) FROM historic").fetchone()[0]
    if existing > 0 and not args.force:
        print(f"  [ATTENTION] La table contient déjà {existing} lignes.")
        print("  Utilise --force pour réimporter depuis zéro.")
        con.close()
        return

    n = insert_entries(con, entries)
    con.close()
    print(f"  {n} entrées insérées dans {db_path}")


if __name__ == "__main__":
    main()
