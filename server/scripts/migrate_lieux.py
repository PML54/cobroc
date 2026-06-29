#!/usr/bin/env python3
"""
Migration : remplace la VIEW lieux par une TABLE, ajoute lieu_id à historic.
Usage    : python scripts/migrate_lieux.py
Idempotent : peut être relancé sans risque.
"""
import os
import sqlite3
import unicodedata
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()
DB_PATH = Path(os.getenv("DB_PATH", "./db/historibroc.db"))


def _noaccent(s: str | None) -> str | None:
    if s is None:
        return None
    return unicodedata.normalize("NFD", s).encode("ascii", "ignore").decode("ascii").upper()


def migrate(db_path: Path) -> None:
    con = sqlite3.connect(db_path)
    try:
        # 1. Supprimer la VIEW si elle existe encore
        con.execute("DROP VIEW IF EXISTS lieux")
        print("  ✓ VIEW lieux supprimée (ou absente)")

        # 2. Créer la TABLE lieux
        con.execute("""
            CREATE TABLE IF NOT EXISTS lieux (
                id               INTEGER PRIMARY KEY AUTOINCREMENT,
                nom              TEXT    NOT NULL DEFAULT '',
                ville            TEXT    NOT NULL,
                ville_normalized TEXT,
                code_postal      INTEGER NOT NULL DEFAULT 0,
                adresse          TEXT    NOT NULL DEFAULT '',
                recurrence       TEXT    NOT NULL DEFAULT '',
                created_at       TEXT    NOT NULL DEFAULT (datetime('now'))
            )
        """)
        con.execute(
            "CREATE INDEX IF NOT EXISTS idx_lieux_ville ON lieux(ville_normalized)"
        )
        print("  ✓ TABLE lieux créée (ou déjà présente)")

        # 3. Ajouter lieu_id à historic si absent
        cols = {row[1] for row in con.execute("PRAGMA table_info(historic)")}
        if "lieu_id" not in cols:
            con.execute(
                "ALTER TABLE historic ADD COLUMN lieu_id INTEGER REFERENCES lieux(id)"
            )
            con.execute(
                "CREATE INDEX IF NOT EXISTS idx_lieu_id ON historic(lieu_id)"
            )
            print("  ✓ Colonne lieu_id ajoutée à historic")
        else:
            print("  ✓ lieu_id déjà présent dans historic")

        con.commit()
        print("\nMigration terminée avec succès.")
    finally:
        con.close()


if __name__ == "__main__":
    print(f"Base : {DB_PATH}\n")
    migrate(DB_PATH)
