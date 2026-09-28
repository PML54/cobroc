"""
tests/test_is_true_duplicate.py
Tests unitaires de agent.validator._is_true_duplicate — détection déterministe
d'un vrai doublon (même hist_name + hist_date + hist_ville normalisée).

Exécution : depuis server/  ->  .venv/bin/python tests/test_is_true_duplicate.py
(ou, en cloud : $HOME/.venv-cobroc/bin/python server/tests/test_is_true_duplicate.py)

RUSTINE ASSUMÉE : validator.py construit un client Anthropic au niveau module
(_client = Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])). Importer une
fonction pure oblige donc à (a) poser ANTHROPIC_API_KEY et (b) avoir le package
anthropic installé. Le setdefault ci-dessous DOIT rester AVANT l'import de
validator : c'est fragile (dépendance à l'ordre d'import). Le fix propre serait
un lazy init du client dans validator.py — chantier séparé, non fait ici.
"""

import os
import sys

# Rendre le package `agent` importable, quel que soit le cwd (server/ sur le path).
_SERVER_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if _SERVER_DIR not in sys.path:
    sys.path.insert(0, _SERVER_DIR)

# Doit précéder l'import de validator (cf. RUSTINE ASSUMÉE ci-dessus).
os.environ.setdefault("ANTHROPIC_API_KEY", "test-dummy-key")

from agent.validator import _is_true_duplicate  # noqa: E402


def _entry(name="PML", date="2026-06-01", ville="NIMES"):
    """Fabrique une entrée Historic minimale (seuls les 3 champs discriminants)."""
    return {"hist_name": name, "hist_date": date, "hist_ville": ville}


# (description, entry, existing_entries, attendu)
CASES = [
    # 1. Vrai doublon exact -> True
    ("doublon exact",
     _entry(), [_entry()], True),

    # 2. Même ville/date, visiteurs différents (PML vs FRA) -> False (sortie conjointe)
    ("meme ville/date, PML vs FRA",
     _entry(name="PML"), [_entry(name="FRA")], False),

    # 3. Villes équivalentes après normalisation (accents + casse) -> True
    ("ville equivalente apres normalisation (Nimes/NIMES)",
     _entry(ville="Nîmes"), [_entry(ville="NIMES")], True),

    # 4. Liste existante vide -> False
    ("existing_entries vide",
     _entry(), [], False),

    # 5. Date différente -> False
    ("date differente",
     _entry(date="2026-06-01"), [_entry(date="2026-06-08")], False),

    # 6. Ville différente -> False
    ("ville differente",
     _entry(ville="NIMES"), [_entry(ville="LYON")], False),

    # 7. Espaces de bord sur les 3 champs -> True (strip appliqué partout)
    ("espaces de bord (strip)",
     _entry(name=" PML ", date=" 2026-06-01 ", ville=" Nîmes "),
     [_entry()], True),

    # 8. Casse du visiteur -> True (comparaison en .upper())
    ("casse visiteur (pml vs PML)",
     _entry(name="pml"), [_entry(name="PML")], True),

    # 9. Doublon non-premier de la liste -> True (parcours complet)
    ("doublon en 3e position",
     _entry(),
     [_entry(name="FRA"), _entry(date="2026-06-08"), _entry()], True),

    # 10. Champs manquants des DEUX côtés -> True (get(...) or "" => "" == "")
    #     Comportement RÉEL documenté (pas forcément souhaitable), pas une garantie.
    ("champs tous manquants des deux cotes",
     {}, [{}], True),

    # 11. Entrée pleine vs entrée vide -> False
    ("entree pleine vs entree vide",
     _entry(), [{}], False),
]


def main():
    failures = []
    for i, (desc, entry, existing, expected) in enumerate(CASES, 1):
        got = _is_true_duplicate(entry, existing)
        ok = got is expected
        print(f"[{'PASS' if ok else 'FAIL'}] {i:>2}. {desc} "
              f"(attendu={expected}, obtenu={got})")
        if not ok:
            failures.append(desc)

    total = len(CASES)
    print(f"\n{total - len(failures)}/{total} tests passés.")
    if failures:
        print("ÉCHECS : " + ", ".join(failures))
        sys.exit(1)


if __name__ == "__main__":
    main()
