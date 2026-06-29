#!/usr/bin/env python3
"""
server.py  —  cobroc-server
API REST pour la base Historic brocantes.
Usage : uvicorn server:app --host 0.0.0.0 --port 8765 --reload
"""

import os
import sqlite3
import unicodedata
from contextlib import contextmanager
from pathlib import Path

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

load_dotenv()

DB_PATH = Path(os.getenv("DB_PATH", "./db/historibroc.db"))
SCHEMA  = Path("db/schema.sql")

app = FastAPI(title="cobroc-server", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
app.mount("/static", StaticFiles(directory="static"), name="static")


@app.get("/", include_in_schema=False)
def root():
    return RedirectResponse("/static/index.html")


# ── DB helpers ─────────────────────────────────────────────────────────────────

def _noaccent(s) -> str | None:
    """Supprime les accents et met en majuscules — pour tri et recherche insensibles aux accents."""
    if s is None:
        return None
    return unicodedata.normalize("NFD", s).encode("ascii", "ignore").decode("ascii").upper()


def _noaccent_collate(a: str, b: str) -> int:
    na, nb = _noaccent(a) or "", _noaccent(b) or ""
    return (na > nb) - (na < nb)


def _init_db():
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect(DB_PATH)
    # schema.sql est un dump (CREATE TABLE sans IF NOT EXISTS) : le rejouer sur une
    # base déjà peuplée échoue ("table historic already exists"). On ne l'applique
    # donc que si la base est vierge (pas encore de table historic).
    exists = con.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name='historic'"
    ).fetchone()
    if not exists:
        con.executescript(SCHEMA.read_text())
        con.commit()
    con.close()


@contextmanager
def _db():
    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row
    con.create_function("NOACCENT", 1, _noaccent)
    con.create_collation("NOACCENT", _noaccent_collate)
    try:
        yield con
    finally:
        con.close()


def _migrate_db():
    """Migrations incrémentales — idempotentes (teste l'existence avant ALTER)."""
    migrations = [
        # (colonne, DDL complet)
        ("heure_arrivee",    "ALTER TABLE historic ADD COLUMN heure_arrivee   TEXT    NOT NULL DEFAULT ''"),
        ("pluie",            "ALTER TABLE historic ADD COLUMN pluie           INTEGER NOT NULL DEFAULT 0"),
        ("arrivee_tard",     "ALTER TABLE historic ADD COLUMN arrivee_tard    INTEGER NOT NULL DEFAULT 0"),
        ("ordre",            "ALTER TABLE historic ADD COLUMN ordre           INTEGER NOT NULL DEFAULT 1"),
        ("endroit_parking",  "ALTER TABLE historic ADD COLUMN endroit_parking INTEGER NOT NULL DEFAULT 0"),
        ("endroit_champ",    "ALTER TABLE historic ADD COLUMN endroit_champ   INTEGER NOT NULL DEFAULT 0"),
        ("endroit_stade",    "ALTER TABLE historic ADD COLUMN endroit_stade   INTEGER NOT NULL DEFAULT 0"),
        ("endroit_place",    "ALTER TABLE historic ADD COLUMN endroit_place   INTEGER NOT NULL DEFAULT 0"),
        ("endroit_rues",     "ALTER TABLE historic ADD COLUMN endroit_rues    INTEGER NOT NULL DEFAULT 0"),
        ("endroit_salle",      "ALTER TABLE historic ADD COLUMN endroit_salle        INTEGER NOT NULL DEFAULT 0"),
        ("qualite_agreable",   "ALTER TABLE historic ADD COLUMN qualite_agreable    INTEGER NOT NULL DEFAULT 0"),
        ("qualite_non_signalee","ALTER TABLE historic ADD COLUMN qualite_non_signalee INTEGER NOT NULL DEFAULT 0"),
        ("qualite_a_faire_a_2","ALTER TABLE historic ADD COLUMN qualite_a_faire_a_2 INTEGER NOT NULL DEFAULT 0"),
    ]
    with _db() as con:
        existing = {row[1] for row in con.execute("PRAGMA table_info(historic)").fetchall()}
        for col, ddl in migrations:
            if col not in existing:
                con.execute(ddl)
        con.commit()


@app.on_event("startup")
def startup():
    _init_db()
    _migrate_db()


# ── Modèles Pydantic ────────────────────────────────────────────────────────────

class LieuIn(BaseModel):
    nom:         str = ""
    ville:       str
    code_postal: int
    adresse:     str = ""
    recurrence:  str = ""
    parking:     int = Field(0, ge=0, le=1)
    rues:        int = Field(0, ge=0, le=1)
    stade:       int = Field(0, ge=0, le=1)
    espace:      int = Field(0, ge=0, le=1)


class LieuOut(BaseModel):
    id:          int
    nom:         str
    ville:       str
    code_postal: int
    adresse:     str
    recurrence:  str
    parking:     int = 0
    rues:        int = 0
    stade:       int = 0
    espace:      int = 0
    created_at:  str
    nb_visites:  int = 0


class HistoricIn(BaseModel):
    hist_name:        str = Field(..., pattern="^(PML|FRA)$")
    hist_date:        str = Field(..., pattern=r"^\d{4}-\d{2}-\d{2}$")
    hist_good:        int = Field(0, ge=0, le=5)
    hist_ville:       str
    hist_code_postal: int
    hist_adresse:     str = ""
    hist_nb_expo:     int = 0
    hist_pml_dep:     int = 0
    hist_fra_dep:     int = 0
    hist_maison_dep:  int = 0
    hist_avis:        str = ""
    hist_detail:      str = ""
    lieu_id:          int | None = None
    heure_arrivee:    str = ""
    pluie:            int = Field(0, ge=0, le=1)
    arrivee_tard:     int = Field(0, ge=0, le=1)
    ordre:            int = Field(1, ge=1, le=5)
    endroit_parking:  int = Field(0, ge=0, le=1)
    endroit_champ:    int = Field(0, ge=0, le=1)
    endroit_stade:    int = Field(0, ge=0, le=1)
    endroit_place:    int = Field(0, ge=0, le=1)
    endroit_rues:     int = Field(0, ge=0, le=1)
    endroit_salle:         int = Field(0, ge=0, le=1)
    qualite_agreable:      int = Field(0, ge=0, le=1)
    qualite_non_signalee:  int = Field(0, ge=0, le=1)
    qualite_a_faire_a_2:   int = Field(0, ge=0, le=1)


class HistoricOut(BaseModel):
    id:               int
    hist_name:        str
    hist_date:        str
    hist_good:        int
    hist_ville:       str
    hist_code_postal: int
    hist_adresse:     str
    hist_nb_expo:     int
    hist_pml_dep:     int
    hist_fra_dep:     int
    hist_maison_dep:  int
    hist_avis:        str
    hist_detail:      str
    validated:        int
    agent_notes:      str
    created_at:       str
    lieu_id:          int | None = None
    heure_arrivee:    str = ""
    pluie:            int = 0
    arrivee_tard:     int = 0
    ordre:            int = 1
    endroit_parking:  int = 0
    endroit_champ:    int = 0
    endroit_stade:    int = 0
    endroit_place:    int = 0
    endroit_rues:     int = 0
    endroit_salle:         int = 0
    qualite_agreable:      int = 0
    qualite_non_signalee:  int = 0
    qualite_a_faire_a_2:   int = 0


# ── Routes ──────────────────────────────────────────────────────────────────────

@app.get("/historic", response_model=list[HistoricOut])
def list_historic(
    ville:     str | None = Query(None),
    name:      str | None = Query(None),
    validated: int | None = Query(None),
    year:      int | None = Query(None),
    sort:      str        = Query("date_desc", pattern="^(date_desc|date_asc|ville_asc|ville_desc)$"),
    limit:     int        = Query(200, le=1000),
    offset:    int        = Query(0),
):
    clauses, params = [], []
    if ville:
        clauses.append("NOACCENT(hist_ville) LIKE NOACCENT(?)")
        params.append(f"{ville}%")          # match en début de ville uniquement
    if name:
        clauses.append("hist_name = ?")
        params.append(name)
    if validated is not None:
        clauses.append("validated = ?")
        params.append(validated)
    if year is not None:
        clauses.append("hist_date LIKE ?")
        params.append(f"{year}-%")

    order = {
        "date_desc":  "hist_date DESC, hist_ville COLLATE NOACCENT ASC",
        "date_asc":   "hist_date ASC,  hist_ville COLLATE NOACCENT ASC",
        "ville_asc":  "hist_ville COLLATE NOACCENT ASC",
        "ville_desc": "hist_ville COLLATE NOACCENT DESC",
    }[sort]

    where = ("WHERE " + " AND ".join(clauses)) if clauses else ""
    sql = f"SELECT * FROM historic {where} ORDER BY {order} LIMIT ? OFFSET ?"
    params += [limit, offset]

    with _db() as con:
        rows = con.execute(sql, params).fetchall()
    return [dict(r) for r in rows]


@app.get("/historic/{entry_id}", response_model=HistoricOut)
def get_historic(entry_id: int):
    with _db() as con:
        row = con.execute("SELECT * FROM historic WHERE id = ?", (entry_id,)).fetchone()
    if not row:
        raise HTTPException(404, "Entrée introuvable")
    return dict(row)


@app.post("/historic", response_model=HistoricOut, status_code=201)
def create_historic(entry: HistoricIn):
    from agent.validator import validate_entry

    with _db() as con:
        # Contexte pour détecter les doublons
        existing = [
            dict(r) for r in con.execute(
                "SELECT hist_name, hist_date, hist_ville FROM historic "
                "WHERE hist_ville = ? ORDER BY hist_date DESC LIMIT 20",
                (entry.hist_ville,),
            ).fetchall()
        ]

    result = validate_entry(entry.model_dump(), existing)
    validated   = 1 if result.get("approved") else 0
    agent_notes = result.get("notes", "")

    # Appliquer les suggestions de l'agent si présentes.
    # Garde-fous :
    #  - champs texte libres (saisis par l'utilisateur) : jamais modifiés
    #  - champ int : uniquement si la suggestion est parsable en int
    NO_SUGGEST = {"hist_avis", "hist_detail", "hist_adresse"}
    data = entry.model_dump()
    int_fields = {f for f, v in data.items() if isinstance(v, int)}
    for field, value in (result.get("suggestions") or {}).items():
        if not value or field not in data or field in NO_SUGGEST:
            continue
        if field in int_fields:
            try:
                data[field] = int(value)
            except (ValueError, TypeError):
                pass   # suggestion illisible → on garde la valeur saisie
        else:
            data[field] = value

    sql = """
        INSERT INTO historic
          (hist_name, hist_date, hist_good, hist_ville, hist_code_postal,
           hist_adresse, hist_nb_expo, hist_pml_dep, hist_fra_dep,
           hist_maison_dep, hist_avis, hist_detail, validated, agent_notes,
           ville_normalized, lieu_id, heure_arrivee, pluie, arrivee_tard,
           ordre, endroit_parking, endroit_champ, endroit_stade, endroit_place, endroit_rues, endroit_salle,
           qualite_agreable, qualite_non_signalee, qualite_a_faire_a_2)
        VALUES
          (:hist_name, :hist_date, :hist_good, :hist_ville, :hist_code_postal,
           :hist_adresse, :hist_nb_expo, :hist_pml_dep, :hist_fra_dep,
           :hist_maison_dep, :hist_avis, :hist_detail, :validated, :agent_notes,
           :ville_normalized, :lieu_id, :heure_arrivee, :pluie, :arrivee_tard,
           :ordre, :endroit_parking, :endroit_champ, :endroit_stade, :endroit_place, :endroit_rues, :endroit_salle,
           :qualite_agreable, :qualite_non_signalee, :qualite_a_faire_a_2)
    """
    data["validated"]        = validated
    data["agent_notes"]      = agent_notes
    data["ville_normalized"] = _noaccent(data["hist_ville"])

    with _db() as con:
        cur = con.execute(sql, data)
        con.commit()
        row = con.execute("SELECT * FROM historic WHERE id = ?", (cur.lastrowid,)).fetchone()

    return dict(row)


@app.put("/historic/{entry_id}", response_model=HistoricOut)
def update_historic(entry_id: int, entry: HistoricIn):
    from agent.validator import validate_entry

    with _db() as con:
        if not con.execute("SELECT 1 FROM historic WHERE id = ?", (entry_id,)).fetchone():
            raise HTTPException(404, "Entrée introuvable")
        existing = [
            dict(r) for r in con.execute(
                "SELECT hist_name, hist_date, hist_ville FROM historic "
                "WHERE hist_ville = ? AND id != ? ORDER BY hist_date DESC LIMIT 20",
                (entry.hist_ville, entry_id),
            ).fetchall()
        ]

    result = validate_entry(entry.model_dump(), existing)
    validated   = 1 if result.get("approved") else 0
    agent_notes = result.get("notes", "")

    data = entry.model_dump()
    int_fields = {f for f, v in data.items() if isinstance(v, int)}
    for field, value in (result.get("suggestions") or {}).items():
        if not value or field not in data:
            continue
        if field in int_fields:
            try:
                data[field] = int(value)
            except (ValueError, TypeError):
                pass
        else:
            data[field] = value

    sql = """
        UPDATE historic SET
          hist_name=:hist_name, hist_date=:hist_date, hist_good=:hist_good,
          hist_ville=:hist_ville, hist_code_postal=:hist_code_postal,
          hist_adresse=:hist_adresse, hist_nb_expo=:hist_nb_expo,
          hist_pml_dep=:hist_pml_dep, hist_fra_dep=:hist_fra_dep,
          hist_maison_dep=:hist_maison_dep, hist_avis=:hist_avis,
          hist_detail=:hist_detail, validated=:validated, agent_notes=:agent_notes,
          ville_normalized=:ville_normalized, lieu_id=:lieu_id,
          heure_arrivee=:heure_arrivee, pluie=:pluie, arrivee_tard=:arrivee_tard,
          ordre=:ordre, endroit_parking=:endroit_parking, endroit_champ=:endroit_champ,
          endroit_stade=:endroit_stade, endroit_place=:endroit_place, endroit_rues=:endroit_rues,
          endroit_salle=:endroit_salle,
          qualite_agreable=:qualite_agreable, qualite_non_signalee=:qualite_non_signalee,
          qualite_a_faire_a_2=:qualite_a_faire_a_2
        WHERE id=:id
    """
    data["validated"]        = validated
    data["agent_notes"]      = agent_notes
    data["ville_normalized"] = _noaccent(data["hist_ville"])
    data["id"]               = entry_id

    with _db() as con:
        con.execute(sql, data)
        con.commit()
        row = con.execute("SELECT * FROM historic WHERE id = ?", (entry_id,)).fetchone()

    return dict(row)


@app.delete("/historic/{entry_id}", status_code=204)
def delete_historic(entry_id: int):
    with _db() as con:
        if not con.execute("SELECT 1 FROM historic WHERE id = ?", (entry_id,)).fetchone():
            raise HTTPException(404, "Entrée introuvable")
        con.execute("DELETE FROM historic WHERE id = ?", (entry_id,))
        con.commit()


@app.get("/lieux", response_model=list[LieuOut])
def list_lieux(
    ville:  str | None = Query(None),
    cp:     int | None = Query(None),
    sort:   str        = Query("ville_asc", pattern="^(ville_asc|ville_desc|visites_desc)$"),
    limit:  int        = Query(500, le=1000),
    offset: int        = Query(0),
):
    clauses, params = [], []
    if ville:
        clauses.append("NOACCENT(l.ville) LIKE NOACCENT(?)")
        params.append(f"{ville}%")          # match en début de ville uniquement
    if cp is not None:
        clauses.append("l.code_postal = ?")
        params.append(cp)

    order = {
        "ville_asc":    "l.ville_normalized ASC",
        "ville_desc":   "l.ville_normalized DESC",
        "visites_desc": "nb_visites DESC",
    }[sort]

    where = ("WHERE " + " AND ".join(clauses)) if clauses else ""
    sql = f"""
        SELECT l.*, COUNT(h.id) AS nb_visites
        FROM lieux l
        LEFT JOIN historic h ON h.lieu_id = l.id
        {where}
        GROUP BY l.id
        ORDER BY {order}
        LIMIT ? OFFSET ?
    """
    params += [limit, offset]

    with _db() as con:
        rows = con.execute(sql, params).fetchall()
    return [dict(r) for r in rows]


@app.get("/lieux/{lieu_id}", response_model=LieuOut)
def get_lieu(lieu_id: int):
    with _db() as con:
        row = con.execute("SELECT * FROM lieux WHERE id = ?", (lieu_id,)).fetchone()
    if not row:
        raise HTTPException(404, "Lieu introuvable")
    return dict(row)


@app.post("/lieux", response_model=LieuOut, status_code=201)
def create_lieu(lieu: LieuIn):
    data = lieu.model_dump()
    data["ville_normalized"] = _noaccent(data["ville"])
    sql = """
        INSERT INTO lieux
          (nom, ville, ville_normalized, code_postal, adresse, recurrence,
           parking, rues, stade, espace)
        VALUES
          (:nom, :ville, :ville_normalized, :code_postal, :adresse, :recurrence,
           :parking, :rues, :stade, :espace)
    """
    with _db() as con:
        cur = con.execute(sql, data)
        con.commit()
        row = con.execute("SELECT * FROM lieux WHERE id = ?", (cur.lastrowid,)).fetchone()
    return dict(row)


@app.put("/lieux/{lieu_id}", response_model=LieuOut)
def update_lieu(lieu_id: int, lieu: LieuIn):
    with _db() as con:
        if not con.execute("SELECT 1 FROM lieux WHERE id = ?", (lieu_id,)).fetchone():
            raise HTTPException(404, "Lieu introuvable")
        data = lieu.model_dump()
        data["ville_normalized"] = _noaccent(data["ville"])
        data["id"] = lieu_id
        con.execute("""
            UPDATE lieux SET
              nom=:nom, ville=:ville, ville_normalized=:ville_normalized,
              code_postal=:code_postal, adresse=:adresse, recurrence=:recurrence,
              parking=:parking, rues=:rues, stade=:stade, espace=:espace
            WHERE id=:id
        """, data)
        con.commit()
        row = con.execute("SELECT * FROM lieux WHERE id = ?", (lieu_id,)).fetchone()
    return dict(row)


@app.delete("/lieux/{lieu_id}", status_code=204)
def delete_lieu(lieu_id: int):
    with _db() as con:
        if not con.execute("SELECT 1 FROM lieux WHERE id = ?", (lieu_id,)).fetchone():
            raise HTTPException(404, "Lieu introuvable")
        count = con.execute(
            "SELECT COUNT(*) FROM historic WHERE lieu_id = ?", (lieu_id,)
        ).fetchone()[0]
        if count > 0:
            raise HTTPException(409, f"Lieu utilisé par {count} entrée(s) historic — suppression impossible")
        con.execute("DELETE FROM lieux WHERE id = ?", (lieu_id,))
        con.commit()


@app.get("/export/dart")
def export_dart():
    """Génère le contenu complet de historibroc.dart depuis la base."""
    from scripts.export_dart import generate_dart
    content = generate_dart(DB_PATH)
    from fastapi.responses import PlainTextResponse
    return PlainTextResponse(content, media_type="text/plain; charset=utf-8")


@app.get("/stats")
def stats():
    with _db() as con:
        total     = con.execute("SELECT COUNT(*) FROM historic").fetchone()[0]
        validated = con.execute("SELECT COUNT(*) FROM historic WHERE validated=1").fetchone()[0]
        pending   = con.execute("SELECT COUNT(*) FROM historic WHERE validated=0").fetchone()[0]
        by_name   = {
            r["hist_name"]: r["cnt"]
            for r in con.execute(
                "SELECT hist_name, COUNT(*) cnt FROM historic GROUP BY hist_name"
            ).fetchall()
        }
    return {"total": total, "validated": validated, "pending": pending, "by_name": by_name}
