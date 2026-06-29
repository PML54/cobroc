#!/usr/bin/env python3
"""
Migration : ajoute les attributs « endroit » au lieu (cases à cocher).
Colonnes booléennes (0/1) : parking, rues, stade, espace.
Usage    : python scripts/migrate_lieu_endroit.py
Idempotent : peut être relancé sans risque.
"""
import os
import sqlite3
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()
DB_PATH = Path(os.getenv("DB_PATH", "./db/historibroc.db"))

ENDROIT_COLS = ("parking", "rues", "stade", "espace")


def migrate(db_path: Path) -> None:
    con = sqlite3.connect(db_path)
    try:
        cols = {row[1] for row in con.execute("PRAGMA table_info(lieux)")}
        for col in ENDROIT_COLS:
            if col not in cols:
                con.execute(
                    f"ALTER TABLE lieux ADD COLUMN {col} INTEGER NOT NULL DEFAULT 0"
                )
                print(f"  ✓ Colonne {col} ajoutée à lieux")
            else:
                print(f"  ✓ {col} déjà présent dans lieux")
        con.commit()
        print("\nMigration terminée avec succès.")
    finally:
        con.close()


if __name__ == "__main__":
    print(f"Base : {DB_PATH}\n")
    migrate(DB_PATH)
