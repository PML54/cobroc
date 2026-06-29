#!/usr/bin/env python3
"""
Normalise les caractères « à risque shell » dans hist_avis et hist_detail.
Remplacements :
  $   -> €
  "   -> « » (alternance par champ : ouvrant puis fermant)
  \\  -> (supprimé)
  `   -> '
  \n \r \t -> espace (puis espaces multiples compactés)

Usage :
  python scripts/normalize_comments.py            # aperçu (dry-run), n'écrit rien
  python scripts/normalize_comments.py --apply     # applique en base
Idempotent : relançable sans risque.
"""
import os
import re
import sqlite3
import sys
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()
DB_PATH = Path(os.getenv("DB_PATH", "./db/historibroc.db"))
FIELDS = ("hist_avis", "hist_detail")


def _quotes(s: str) -> str:
    """Remplace les " droits :
    - entre deux lettres -> apostrophe ' (élision mal stockée : C"est -> C'est)
    - sinon -> « … » en alternant ouvrant/fermant.
    (À lancer APRÈS suppression des antislashs pour avoir le bon contexte.)"""
    out, opening = [], True
    for i, ch in enumerate(s):
        if ch == '"':
            prev = s[i - 1] if i > 0 else ""
            nxt  = s[i + 1] if i + 1 < len(s) else ""
            if prev.isalpha() and nxt.isalpha():
                out.append("'")
            else:
                out.append("«" if opening else "»")
                opening = not opening
        else:
            out.append(ch)
    return "".join(out)


def normalize(s: str | None) -> str:
    if not s:
        return s or ""
    had_control = bool(re.search(r"[\n\r\t]", s))
    s = s.replace("$", "€")
    s = s.replace("\\", "")     # retirer les antislashs d'abord
    s = s.replace("`", "'")
    s = _quotes(s)              # puis traiter les guillemets avec le bon contexte
    if had_control:
        # uniquement quand on a transformé des sauts de ligne/tab en espaces
        s = re.sub(r"[\n\r\t]+", " ", s)
        s = re.sub(r" {2,}", " ", s).strip()
    return s


def run(apply: bool) -> None:
    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row
    rows = con.execute(f"SELECT id, {', '.join(FIELDS)} FROM historic").fetchall()

    changes = []
    for r in rows:
        updates = {}
        for f in FIELDS:
            new = normalize(r[f])
            if new != (r[f] or ""):
                updates[f] = new
        if updates:
            changes.append((r["id"], r, updates))

    print(f"{len(rows)} lignes — {len(changes)} à modifier\n")
    for _id, r, updates in changes[:40]:
        for f, new in updates.items():
            print(f"  id {_id} [{f}]")
            print(f"    - {r[f]!r}")
            print(f"    + {new!r}")
    if len(changes) > 40:
        print(f"  … (+{len(changes) - 40} autres)")

    if apply and changes:
        for _id, _r, updates in changes:
            sets = ", ".join(f"{f}=?" for f in updates)
            con.execute(f"UPDATE historic SET {sets} WHERE id=?",
                        (*updates.values(), _id))
        con.commit()
        print(f"\n✓ {len(changes)} lignes mises à jour.")
    elif not apply:
        print("\n(dry-run — rien écrit. Relancer avec --apply pour appliquer.)")
    con.close()


if __name__ == "__main__":
    print(f"Base : {DB_PATH}\n")
    run(apply="--apply" in sys.argv)
