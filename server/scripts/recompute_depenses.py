#!/usr/bin/env python3
"""
Recalcule integralement les depenses de la table `historic` depuis `hist_detail`.

REGLE (decision projet, sans exception) :
  hist_maison_dep = 0                       pour TOUS les enregistrements
  hist_name = 'PML'  ->  hist_pml_dep = somme des prix du detail, hist_fra_dep = 0
  hist_name = 'FRA'  ->  hist_fra_dep = somme des prix du detail, hist_pml_dep = 0

La valeur existante n'est jamais prise en compte : le detail fait foi, seul.
Les items sans prix comptent pour 0. Un detail vide donne donc une depense de 0,
MEME si un montant etait enregistre (voir la categorie PERTE ci-dessous).

Categories du rapport :
  RECALCUL   le detail contient au moins un prix -> depense = somme de ces prix
  PERTE      le detail ne contient aucun prix mais un montant etait enregistre
             -> il tombe a 0. C'est la consequence assumee de la regle, mais
                ces lignes sont isolees pour que la perte reste visible.
  MAISON     seul hist_maison_dep changeait (remis a 0)

Usage :
  python scripts/recompute_depenses.py                  # dry-run
  python scripts/recompute_depenses.py --csv rap.csv     # dry-run + CSV
  python scripts/recompute_depenses.py --only PERTE      # filtre
  python scripts/recompute_depenses.py --apply           # ecrit (backup auto)

Idempotent : relançable sans risque.
"""
import argparse
import csv
import os
import re
import shutil
import sqlite3
import sys
from datetime import datetime
from pathlib import Path

try:
    from dotenv import load_dotenv

    load_dotenv()
except ModuleNotFoundError:
    _env = Path(__file__).resolve().parent.parent / ".env"
    if _env.exists():
        for _l in _env.read_text(encoding="utf-8").splitlines():
            _l = _l.strip()
            if _l and not _l.startswith("#") and "=" in _l:
                _k, _, _v = _l.partition("=")
                os.environ.setdefault(_k.strip(), _v.strip().strip("\"'"))

DB_PATH = Path(os.getenv("DB_PATH", "./db/historibroc.db"))

RE_CANON_ITEM = re.compile(r"^(.+?)=(\d+)€$")


def somme_detail(detail: str | None) -> int:
    """Somme des prix des items qui en portent un, en excluant ceux dont l'avis
    est "MAISON". 0 si aucun.

    Format d'un item : "desc=prix€|avis|vendu" (| intra-item). Un item dont le
    segment avis vaut "MAISON" (insensible a la casse) n'est pas compte.
    """
    total = 0
    for p in (detail or "").split("+"):
        if not p.strip():
            continue
        segs = p.split("|")
        avis = segs[1].strip().upper() if len(segs) > 1 else ""
        if avis == "MAISON":
            continue
        m = RE_CANON_ITEM.match(segs[0])
        if m:
            total += int(m.group(2))
    return total


def calculer(row) -> dict | None:
    """Retourne le changement a appliquer, ou None si la ligne est deja conforme."""
    nom = (row["hist_name"] or "").upper()
    pml, fra, maison = row["hist_pml_dep"], row["hist_fra_dep"], row["hist_maison_dep"]
    if nom not in ("PML", "FRA"):
        return None

    total = somme_detail(row["hist_detail"])
    n_pml, n_fra = (total, 0) if nom == "PML" else (0, total)

    if (n_pml, n_fra, 0) == (pml, fra, maison):
        return None

    if total == 0 and (pml or fra):
        categorie = "PERTE"
    elif (n_pml, n_fra) == (pml, fra):
        categorie = "MAISON"
    else:
        categorie = "RECALCUL"

    return {
        "id": row["id"],
        "date": row["hist_date"],
        "ville": row["hist_ville"],
        "name": nom,
        "categorie": categorie,
        "pml_avant": pml,
        "fra_avant": fra,
        "maison_avant": maison,
        "pml_apres": n_pml,
        "fra_apres": n_fra,
        "somme_detail": total,
        "delta": (n_pml + n_fra) - (pml + fra),
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--apply", action="store_true", help="ecrit en base")
    ap.add_argument("--csv", metavar="FICHIER", help="export du rapport en CSV")
    ap.add_argument("--only", choices=("RECALCUL", "PERTE", "MAISON"), help="restreint le lot")
    ap.add_argument("--limit", type=int, default=20, help="lignes affichees par categorie")
    args = ap.parse_args()

    if not DB_PATH.exists():
        print(f"Base introuvable : {DB_PATH}", file=sys.stderr)
        return 1

    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row
    rows = con.execute(
        "SELECT id, hist_date, hist_ville, hist_name, hist_pml_dep, hist_fra_dep, "
        "hist_maison_dep, hist_detail FROM historic ORDER BY id"
    ).fetchall()

    chg = [c for c in (calculer(r) for r in rows) if c]

    print(f"\nBase : {DB_PATH}")
    print(f"Lignes totales : {len(rows)} — a corriger : {len(chg)}\n")
    for cat in ("RECALCUL", "PERTE", "MAISON"):
        lot = [x for x in chg if x["categorie"] == cat]
        delta = sum(x["delta"] for x in lot)
        print(f"  {cat:<10} {len(lot):>5}   delta depenses {delta:+}")
    print(f"\n  delta total : {sum(x['delta'] for x in chg):+} €")
    print(f"  maison remis a 0 : {sum(1 for x in chg if x['maison_avant'])} lignes, "
          f"{-sum(x['maison_avant'] for x in chg)} €")

    for cat in ("RECALCUL", "PERTE", "MAISON"):
        if args.only and cat != args.only:
            continue
        lot = [x for x in chg if x["categorie"] == cat]
        if not lot:
            continue
        print(f"\n=== {cat} — {len(lot)} lignes ===")
        for x in lot[: args.limit]:
            print(
                f"  #{x['id']:<5} {x['date']} {x['ville'][:18]:<18} {x['name']} | "
                f"pml {x['pml_avant']:>4}->{x['pml_apres']:<4} "
                f"fra {x['fra_avant']:>4}->{x['fra_apres']:<4} "
                f"maison {x['maison_avant']:>4}->0 | detail {x['somme_detail']}"
            )
        if len(lot) > args.limit:
            print(f"  … {len(lot) - args.limit} autres (voir --csv)")

    if args.csv:
        with open(args.csv, "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=list(chg[0].keys()) if chg else ["id"])
            w.writeheader()
            w.writerows(chg)
        print(f"\nRapport CSV ecrit : {args.csv}")

    if not args.apply:
        print("\n[dry-run] Rien n'a ete ecrit. Ajouter --apply pour appliquer.")
        return 0

    cibles = [x for x in chg if not args.only or x["categorie"] == args.only]
    if not cibles:
        print("\nRien a appliquer.")
        return 0

    stamp = datetime.now().strftime("%y%m%d%H%M")
    backup = DB_PATH.with_name(f"{DB_PATH.stem}.backup-{stamp}-avant-depenses.db")
    shutil.copy2(DB_PATH, backup)
    print(f"\nBackup : {backup}")

    con.executemany(
        "UPDATE historic SET hist_pml_dep = ?, hist_fra_dep = ? WHERE id = ?",
        [(x["pml_apres"], x["fra_apres"], x["id"]) for x in cibles],
    )
    print(f"{len(cibles)} lignes recalculees (pml/fra).")

    # hist_maison_dep est remis a 0 sur TOUTE la table, sans condition et sans
    # tenir compte de --only : c'est une regle globale, pas une reparation.
    cur = con.execute("UPDATE historic SET hist_maison_dep = 0 WHERE hist_maison_dep != 0")
    print(f"{cur.rowcount} lignes avec hist_maison_dep remis a 0.")
    con.commit()
    print("Penser ensuite a : python3 scripts/export_dart.py")
    return 0


if __name__ == "__main__":
    sys.exit(main())
