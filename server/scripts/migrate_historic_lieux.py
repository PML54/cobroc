#!/usr/bin/env python3
"""
Migration : peuple la TABLE lieux depuis historic et relie lieu_id sur chaque ligne.
Groupement : (ville_normalized, hist_code_postal, hist_adresse)
Usage     : python scripts/migrate_historic_lieux.py
Idempotent : ne recrée pas les lieux déjà présents.
"""
import os
import sqlite3
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()
DB_PATH = Path(os.getenv("DB_PATH", "./db/historibroc.db"))


def migrate(db_path: Path) -> None:
    con = sqlite3.connect(db_path)
    con.row_factory = sqlite3.Row
    try:
        # Groupes distincts non encore reliés
        groupes = con.execute("""
            SELECT
                ville_normalized,
                hist_code_postal,
                hist_adresse,
                -- hist_ville canonique : la version la plus fréquente du groupe
                (
                    SELECT hist_ville FROM historic h2
                    WHERE h2.ville_normalized  = h.ville_normalized
                      AND h2.hist_code_postal  = h.hist_code_postal
                      AND h2.hist_adresse      = h.hist_adresse
                    GROUP BY hist_ville ORDER BY COUNT(*) DESC LIMIT 1
                ) AS ville_canon,
                COUNT(*) AS nb
            FROM historic h
            WHERE lieu_id IS NULL
            GROUP BY ville_normalized, hist_code_postal, hist_adresse
            ORDER BY ville_normalized, hist_adresse
        """).fetchall()

        print(f"{len(groupes)} lieux distincts à créer\n")

        created = updated = 0

        for g in groupes:
            # Lieu déjà créé (cas idempotent) ?
            existing = con.execute("""
                SELECT id FROM lieux
                WHERE ville_normalized = ? AND code_postal = ? AND adresse = ?
            """, (g["ville_normalized"], g["hist_code_postal"], g["hist_adresse"])).fetchone()

            if existing:
                lieu_id = existing["id"]
            else:
                cur = con.execute("""
                    INSERT INTO lieux (nom, ville, ville_normalized, code_postal, adresse, recurrence)
                    VALUES ('', ?, ?, ?, ?, '')
                """, (g["ville_canon"], g["ville_normalized"],
                      g["hist_code_postal"], g["hist_adresse"]))
                lieu_id = cur.lastrowid
                created += 1

            n = con.execute("""
                UPDATE historic SET lieu_id = ?
                WHERE lieu_id IS NULL
                  AND ville_normalized  = ?
                  AND hist_code_postal  = ?
                  AND hist_adresse      = ?
            """, (lieu_id, g["ville_normalized"],
                  g["hist_code_postal"], g["hist_adresse"])).rowcount
            updated += n

        con.commit()

        total_lieux = con.execute("SELECT COUNT(*) FROM lieux").fetchone()[0]
        unlinked    = con.execute("SELECT COUNT(*) FROM historic WHERE lieu_id IS NULL").fetchone()[0]

        print(f"  ✓ {created} lieux créés")
        print(f"  ✓ {updated} entrées historic reliées")
        print(f"  ✓ {total_lieux} lieux au total")
        if unlinked:
            print(f"  ⚠  {unlinked} entrées historic sans lieu_id (à investiguer)")
        else:
            print("  ✓ toutes les entrées historic ont un lieu_id")
        print("\nMigration terminée.")

    finally:
        con.close()


if __name__ == "__main__":
    print(f"Base : {DB_PATH}\n")
    migrate(DB_PATH)
