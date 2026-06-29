#!/usr/bin/env python3
"""
Migration : ajoute des observations de visite à historic.
- heure_arrivee TEXT  (format "HH:MM", '' si non saisi)
- pluie         INTEGER 0/1
- arrivee_tard  INTEGER 0/1
Usage    : python scripts/migrate_historic_conditions.py
Idempotent : peut être relancé sans risque.
"""
import os
import sqlite3
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()
DB_PATH = Path(os.getenv("DB_PATH", "./db/historibroc.db"))

NEW_COLS = {
    "heure_arrivee": "TEXT    NOT NULL DEFAULT ''",
    "pluie":         "INTEGER NOT NULL DEFAULT 0",
    "arrivee_tard":  "INTEGER NOT NULL DEFAULT 0",
}


def migrate(db_path: Path) -> None:
    con = sqlite3.connect(db_path)
    try:
        cols = {row[1] for row in con.execute("PRAGMA table_info(historic)")}
        for name, decl in NEW_COLS.items():
            if name not in cols:
                con.execute(f"ALTER TABLE historic ADD COLUMN {name} {decl}")
                print(f"  ✓ Colonne {name} ajoutée à historic")
            else:
                print(f"  ✓ {name} déjà présent dans historic")
        con.commit()
        print("\nMigration terminée avec succès.")
    finally:
        con.close()


if __name__ == "__main__":
    print(f"Base : {DB_PATH}\n")
    migrate(DB_PATH)
