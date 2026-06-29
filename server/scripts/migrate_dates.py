#!/usr/bin/env python3
"""
scripts/migrate_dates.py
Migration one-shot : convertit hist_date de JJ/MM/AAAA → AAAA-MM-JJ dans la base SQLite.
Usage : python scripts/migrate_dates.py [--db PATH]
"""

import shutil
import sqlite3
import argparse
from pathlib import Path

DEFAULT_DB = Path(__file__).parent.parent / "db/historibroc.db"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default=str(DEFAULT_DB))
    args = ap.parse_args()
    db_path = Path(args.db)

    # Sauvegarde avant migration
    backup = db_path.with_suffix(".db.bak")
    shutil.copy2(db_path, backup)
    print(f"Sauvegarde : {backup}")

    con = sqlite3.connect(db_path)

    # Compter les lignes à migrer (format JJ/MM/AAAA)
    to_migrate = con.execute(
        "SELECT COUNT(*) FROM historic WHERE hist_date LIKE '__/__/____'"
    ).fetchone()[0]
    print(f"Lignes à convertir : {to_migrate}")

    if to_migrate == 0:
        print("Rien à faire — les dates sont déjà au format AAAA-MM-JJ.")
        con.close()
        return

    con.execute("""
        UPDATE historic
        SET hist_date = substr(hist_date,7,4) || '-' || substr(hist_date,4,2) || '-' || substr(hist_date,1,2)
        WHERE hist_date LIKE '__/__/____'
    """)
    con.commit()

    remaining = con.execute(
        "SELECT COUNT(*) FROM historic WHERE hist_date LIKE '__/__/____'"
    ).fetchone()[0]
    con.close()

    if remaining == 0:
        print(f"[OK] {to_migrate} dates converties en AAAA-MM-JJ.")
    else:
        print(f"[ATTENTION] {remaining} lignes n'ont pas pu être converties.")


if __name__ == "__main__":
    main()
