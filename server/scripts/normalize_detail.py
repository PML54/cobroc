#!/usr/bin/env python3
"""
Uniformise le champ `hist_detail` de la table `historic` au format canonique :

    desc=prix€+desc=prix€+…          (+ = separateur inter-items)
    desc=prix€|avis|vendu+…          (| = separateur intra-item, preserve tel quel)

Regles de conversion :
  - Detection des prix quelle que soit leur position (avant ou apres la description).
  - Decimales perdues reconstruites ("4 5€" -> 4,50) puis ARRONDIES A L'EURO
    SUPERIEUR (ceil), conformement a la decision projet : pas de decimales.
  - Separateurs sources acceptes : '+', ' - ', '€-', ' . ' et fin de chaine.
  - Un item deja au format `desc=prix€` est laisse intact (idempotence).

Classement de chaque entree :
  OK        -> tous les items parses avec exactement un prix : conversion sure
  DOUTEUX   -> au moins un item ambigu (0 ou >1 prix, decimale reconstruite,
               description vide) : converti mais A RELIRE
  MANUEL    -> aucun prix trouve dans toute l'entree (souvent un commentaire
               range par erreur dans hist_detail) : LAISSE INTACT

Usage :
  python scripts/normalize_detail.py                 # dry-run, rapport console
  python scripts/normalize_detail.py --csv rap.csv   # dry-run + export CSV
  python scripts/normalize_detail.py --only DOUTEUX  # filtre l'affichage
  python scripts/normalize_detail.py --apply         # ecrit en base (backup auto)
  python scripts/normalize_detail.py --apply --only OK   # applique les seuls surs

Le mode --apply cree d'abord db/historibroc.backup-<YYMMDDHHMM>-avant-detail.db
et n'ecrit JAMAIS les entrees classees MANUEL.
Idempotent : relançable sans risque.
"""
import argparse
import csv
import math
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
    # python-dotenv n'est installe que dans server/.venv. Le script n'a besoin
    # que de DB_PATH : on lit le .env a la main plutot que d'echouer.
    _env = Path(__file__).resolve().parent.parent / ".env"
    if _env.exists():
        for _ligne in _env.read_text(encoding="utf-8").splitlines():
            _ligne = _ligne.strip()
            if _ligne and not _ligne.startswith("#") and "=" in _ligne:
                _cle, _, _val = _ligne.partition("=")
                os.environ.setdefault(_cle.strip(), _val.strip().strip("\"'"))

DB_PATH = Path(os.getenv("DB_PATH", "./db/historibroc.db"))

# ── Expressions regulieres ───────────────────────────────────────────────────

# Prix deja canonique : "12€" colle a un '=' en amont.
RE_CANON_ITEM = re.compile(r"^(?P<desc>.+?)=(?P<prix>\d+)€$")

# Un prix dans du texte libre. Groupe 'ent' = partie entiere,
# 'dec' = decimale perdue (1 a 2 chiffres separes par des espaces).
# Le '€' (ou 'cts'/'euros') est requis, sinon trop de faux positifs sur les
# quantites ("2 poupees", "18 OEUFS").
# Le lookbehind exclut seulement chiffre/virgule/point : "couteau4€" doit
# matcher (prix colle au mot, frequent dans la saisie d'origine).
RE_PRIX = re.compile(
    r"(?<![\d,.])(?P<ent>\d{1,4})(?:(?P<sep>\s*[.,]\s*|\s+)(?P<dec>\d{1,2}))?\s*(?P<dev>€|cts\b|euros?\b|eur\b)",
    re.IGNORECASE,
)

# Item deja delimite par '=' mais avec un prix nu ("boite boutons = 8",
# "1 plaque emaillé =0 5"). La devise est alors facultative.
RE_EGAL_NU = re.compile(
    r"^(?P<desc>.+?)\s*=+\s*(?P<ent>\d{1,4})(?:(?P<sep>\s*[.,]\s*|\s+)(?P<dec>\d{1,2}))?"
    r"\s*(?:€|cts\b|euros?\b)?\s*$",
    re.IGNORECASE,
)

# Separateurs inter-items, du plus sur au moins sur.
RE_SPLIT = re.compile(
    r"""
      \s*\+\s*            # '+' : separateur canonique
    | (?<=€)\s*-\s*       # '-' juste apres un '€'
    | \s+-\s+             # '-' entoure d'espaces
    | \s+\.\s+            # '.' entoure d'espaces
    """,
    re.VERBOSE,
)

# Prix NU en fin d'item : aucune devise, le nombre final fait office de prix
# ("3 pots VIlleroy et Boch  3", "livres pour Paul15", "Arts menagers de 12 no 3").
# Contraintes volontairement strictes pour limiter les faux positifs :
#   - le nombre doit terminer l'item (une quantite se place en tete) ;
#   - il doit etre precede d'au moins un mot alphabetique (sinon "4 porte cles"
#     verrait sa quantite promue en prix) ;
#   - max 3 chiffres pour la partie entiere.
RE_PRIX_NU = re.compile(
    r"^(?P<desc>.*[^\W\d_].*?)(?<![\d,.])(?P<ent>\d{1,3})"
    r"(?:(?P<sep>\s*[.,]\s*|\s+)(?P<dec>\d{1,2}))?\s*$"
)

# Bruit a retirer en tete/queue de description.
RE_TRIM = re.compile(r"^[\s\-–—.,;:+*/]+|[\s\-–—.,;:+*/]+$")


# Au-dela de ce seuil, "<ent> <dec>€" n'est plus lu comme une decimale mais
# comme "<description finissant par un nombre> <prix>" : "boite 70  4€" est une
# boite des annees 70 a 4€, pas un objet a 70,40€. Les prix decimaux reels de
# brocante sont petits (0,50 / 2,50 / 6,50…).
SEUIL_DECIMALE = 20


def _euro(ent: str, dec: str | None, sep_explicite: bool = True) -> tuple[int, bool]:
    """Retourne (prix arrondi a l'euro superieur, decimale_reconstruite).

    `sep_explicite` : True si la decimale etait separee par ',' ou '.'
    (fiable), False si elle l'etait par une espace (heuristique).
    """
    if dec is None:
        return int(ent), False
    if not sep_explicite and int(ent) > SEUIL_DECIMALE:
        # On refuse la lecture decimale : cf. SEUIL_DECIMALE.
        return int(dec), False
    # "4 5" -> 4,50 ; "0 50" -> 0,50 ; "6 50" -> 6,50
    return math.ceil(int(ent) + float(f"0.{dec}")), True


def _clean(s: str) -> str:
    s = re.sub(r"\s{2,}", " ", s)
    return RE_TRIM.sub("", s).strip()


def parse_item(chunk: str) -> tuple[str | None, list[str]]:
    """Convertit un item en 'desc=prix€'. Retourne (resultat, alertes)."""
    alerts: list[str] = []

    # Suffixe intra-item '|avis|vendu' : mis de cote, restitue tel quel.
    head, sep, tail = chunk.partition("|")
    suffix = sep + tail if sep else ""

    head = head.strip()
    if not head:
        return None, ["item vide"]

    # Deja canonique -> on ne touche pas.
    if RE_CANON_ITEM.match(head):
        return head + suffix, []

    prix_trouves = list(RE_PRIX.finditer(head))

    # Cas "desc = 8" / "desc =0 5" : l'utilisateur a deja pose le '=',
    # la devise manque. On fait confiance au '=' comme delimiteur.
    if len(prix_trouves) <= 1:
        eg = RE_EGAL_NU.match(head)
        if eg and (not prix_trouves or prix_trouves[0].start() >= eg.start("ent")):
            prix, reconstruit = _euro(
                eg.group("ent"), eg.group("dec"), bool(eg.group("sep") and eg.group("sep").strip())
            )
            desc = _clean(eg.group("desc"))
            if reconstruit:
                alerts.append(f"decimale '{eg.group(0).strip()}' -> {prix}€ (arrondi sup.)")
            if not desc:
                return None, ["item vide"]
            return f"{desc}={prix}€" + suffix, alerts

    if not prix_trouves:
        # Dernier recours : prix nu en fin d'item, sans devise.
        nu = RE_PRIX_NU.match(head)
        if nu:
            prix, reconstruit = _euro(
                nu.group("ent"), nu.group("dec"), bool(nu.group("sep") and nu.group("sep").strip())
            )
            desc = _clean(nu.group("desc"))
            if desc:
                alerts.append(f"prix nu '{nu.group(0)[len(nu.group('desc')):].strip()}' -> {prix}€")
                if reconstruit:
                    alerts.append(f"decimale -> {prix}€ (arrondi sup.)")
                # Sans devise, _resplit ne peut pas detecter les items colles :
                # "boutos anciens 6   eau de cologne 1" reste un seul item et
                # avale le 6. On signale tout nombre isole restant en milieu de
                # description, quasi-certain marqueur d'items fusionnes.
                if re.search(r"(?<![\w,.])\d{1,3}(?:[.,\s]\d{1,2})?\s+[^\W\d_]", desc):
                    alerts.append("nombre isole dans la description : items possiblement fusionnes")
                return f"{desc}={prix}€" + suffix, alerts
        return _clean(head) + suffix, ["aucun prix"]

    if len(prix_trouves) > 1:
        alerts.append(f"{len(prix_trouves)} prix dans un meme item")

    m = prix_trouves[0]
    sep_explicite = bool(m.group("sep") and m.group("sep").strip())
    prix, reconstruit = _euro(m.group("ent"), m.group("dec"), sep_explicite)

    # Debut reel du prix : si la lecture decimale a ete refusee, la partie
    # entiere appartient en fait a la description ("boite 70" + prix "4€").
    debut_prix = m.start() if (m.group("dec") is None or reconstruit) else m.start("dec")

    if reconstruit:
        alerts.append(f"decimale '{m.group(0).strip()}' -> {prix}€ (arrondi sup.)")
    if m.group("dev").lower().startswith("cts"):
        alerts.append("unite 'cts' interpretee en euros")

    # La description = tout sauf le prix (qui peut etre avant ou apres).
    desc = _clean(head[:debut_prix] + " " + head[m.end() :])
    if not desc:
        alerts.append("description vide")
        desc = "?"

    return f"{desc}={prix}€" + suffix, alerts


# REPARATION DES ITEMS FUSIONNES
# Un item canonique dont la DESCRIPTION contient encore "<mots> <nombre>" suivi
# d'un mot est en realite plusieurs objets colles, separes a l'origine par de
# simples espaces multiples que le decoupage n'a pas vus :
#   "15 torchons anciens 5 lot broches 1 50 plaque decorative=3€"
#   -> "15 torchons anciens=5€ + lot broches=2€ + plaque decorative=3€"
# Le nombre doit etre PRECEDE d'une espace (sinon "15 torchons" en tete de
# description verrait sa quantite prise pour un prix) et SUIVI d'un mot.
# Le mot QUI SUIT doit faire au moins 2 lettres : "Cartes 70 s" designe une
# serie des annees 70, pas un objet a 70€ suivi d'un objet nomme "s".
RE_FUSION = re.compile(
    r"(?<=\s)(?P<ent>\d{1,3})(?:(?P<sep>[.,\s])(?P<dec>\d{1,2}))?(?=\s+[^\W\d_]{2,})"
)

# La description qui PRECEDE doit compter au moins 2 mots alphabetiques, sinon
# le nombre est presque toujours une QUANTITE portant sur ce qui suit :
# "lot 8 ramequins anglais" = 8 ramequins, pas un "lot" a 8€.
MOTS_MINI_AVANT_PRIX = 2


def _nb_mots(s: str) -> int:
    return len(re.findall(r"[^\W\d_]{2,}", s))


def defusionner(item: str) -> tuple[list[str], bool] | None:
    """Eclate un item canonique dont la description contient d'autres objets.

    Retourne (liste d'items canoniques, une_decimale_reconstruite) ou None.
    """
    m = RE_CANON_ITEM.match(item)
    if not m:
        return None
    desc, prix_final = m.group("desc"), m.group("prix")
    coupes = list(RE_FUSION.finditer(desc))
    if not coupes:
        return None

    sortie, precedent, reconstruit = [], 0, False
    for c in coupes:
        sous_desc = _clean(desc[precedent : c.start()])
        if _nb_mots(sous_desc) < MOTS_MINI_AVANT_PRIX:
            return None  # quantite, pas un prix : on renonce sur tout l'item
        prix, rec = _euro(c.group("ent"), c.group("dec"), bool((c.group("sep") or "").strip()))

        # La sous-description peut contenir elle-meme un prix explicite
        # ("sac lancel ancien 20eur") : il prime sur le nombre de coupure.
        interne = list(RE_PRIX.finditer(sous_desc))
        if interne:
            reparse, _ = parse_item(sous_desc)
            if reparse and RE_CANON_ITEM.match(reparse):
                sortie.append(reparse)
                precedent = c.end()
                continue

        reconstruit = reconstruit or rec
        sortie.append(f"{sous_desc}={prix}€")
        precedent = c.end()

    reste = _clean(desc[precedent:])
    if not reste:
        return None
    sortie.append(f"{reste}={prix_final}€")
    return sortie, reconstruit


def _resplit(chunk: str) -> list[str]:
    """Re-decoupe un chunk contenant plusieurs prix (separateur oublie).

    L'orientation est deduite du chunk lui-meme : s'il commence par un prix,
    la description SUIT le prix -> on coupe AVANT chaque prix ; sinon la
    description PRECEDE le prix -> on coupe APRES chaque prix.
    """
    if "|" in chunk:  # suffixe intra-item : on ne touche pas
        return [chunk]
    prix = list(RE_PRIX.finditer(chunk))
    if len(prix) < 2:
        return [chunk]

    prix_en_tete = prix[0].start() <= 1
    bornes = [m.start() for m in prix[1:]] if prix_en_tete else [m.end() for m in prix[:-1]]

    morceaux, precedent = [], 0
    for b in bornes:
        morceaux.append(chunk[precedent:b])
        precedent = b
    morceaux.append(chunk[precedent:])
    return [m for m in morceaux if m.strip()]


def parse_detail(detail: str) -> tuple[str, str, list[str]]:
    """Retourne (nouvelle_valeur, statut, alertes) pour un hist_detail complet."""
    src = (detail or "").strip()
    if not src:
        return "", "VIDE", []

    # Fast path : deja entierement canonique.
    # Garantit l'idempotence, y compris quand une description contient un
    # caractere qui sert par ailleurs de separateur (' . ', ' - ').
    # Seule exception : un item dont la description cache d'autres objets
    # (items fusionnes) -> on repare.
    parts = [p for p in src.split("+") if p.strip()]
    if all(RE_CANON_ITEM.match(p.partition("|")[0]) for p in parts):
        sortie, alerts = [], []
        for p in parts:
            tete, sep, queue = p.partition("|")
            eclat = defusionner(tete)
            if eclat:
                items_e, rec = eclat
                alerts.append(f"item fusionne eclate en {len(items_e)}")
                if rec:
                    alerts.append("decimale reconstruite (arrondi sup.)")
                items_e[-1] += sep + queue if sep else ""
                sortie.extend(items_e)
            else:
                sortie.append(p)
        if not alerts:
            return src, "OK", []
        return "+".join(sortie), "DEFUSION", alerts

    chunks = []
    for c in RE_SPLIT.split(src):
        if c and c.strip():
            chunks.extend(_resplit(c))
    items: list[str] = []
    alerts: list[str] = []

    for chunk in chunks:
        out, a = parse_item(chunk)
        if out:
            items.append(out)
        alerts.extend(a)

    nouveau = "+".join(items)

    # Aucun item n'a pu etre converti en 'desc=prix€' -> ce n'est pas une liste
    # d'achats (souvent un commentaire range par erreur dans hist_detail).
    # On teste le RESULTAT et non la source : les saisies du type
    # "collier =3 + rouleau pansement = 5" n'ont pas de '€' mais sont bien
    # parsables via RE_EGAL_NU.
    if not any(RE_CANON_ITEM.match(i.partition("|")[0]) for i in items):
        return src, "MANUEL", ["aucun prix exploitable dans l'entree"]

    # "aucun prix" n'est pas une erreur : le formulaire web sait relire un item
    # reduit a sa description (fillAchatsFromDetail -> addAchatRow(item, '')).
    # La conversion reste donc sans perte -> statut OK, mention conservee.
    bloquantes = [a for a in alerts if a != "aucun prix"]
    n_sans_prix = len(alerts) - len(bloquantes)
    if n_sans_prix:
        bloquantes_txt = bloquantes + [f"{n_sans_prix} item(s) sans prix"]
    else:
        bloquantes_txt = bloquantes

    statut = "OK" if not bloquantes else "DOUTEUX"
    return nouveau, statut, bloquantes_txt


# ── Pilotage ─────────────────────────────────────────────────────────────────


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--apply", action="store_true", help="ecrit en base")
    ap.add_argument("--csv", metavar="FICHIER", help="export du rapport en CSV")
    ap.add_argument(
        "--only",
        choices=("OK", "DOUTEUX", "DEFUSION", "MANUEL"),
        help="restreint l'affichage (et l'ecriture avec --apply)",
    )
    ap.add_argument("--limit", type=int, default=25, help="lignes affichees par statut")
    ap.add_argument(
        "--sans",
        metavar="MOTIF",
        help="exclut les entrees dont les alertes contiennent MOTIF (ex: fusionnes)",
    )
    ap.add_argument(
        "--ids",
        metavar="LISTE",
        help="restreint a ces id (ex: 53,60,64) ou @fichier (un id par ligne)",
    )
    args = ap.parse_args()

    ids_cibles: set[int] | None = None
    if args.ids:
        brut = Path(args.ids[1:]).read_text().split() if args.ids.startswith("@") else args.ids.split(",")
        ids_cibles = {int(x) for x in brut if x.strip()}

    if not DB_PATH.exists():
        print(f"Base introuvable : {DB_PATH}", file=sys.stderr)
        return 1

    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row
    rows = con.execute(
        "SELECT id, hist_date, hist_ville, hist_detail FROM historic "
        "WHERE hist_detail != '' ORDER BY id"
    ).fetchall()

    resultats = []
    for r in rows:
        nouveau, statut, alerts = parse_detail(r["hist_detail"])
        change = nouveau != r["hist_detail"]
        resultats.append(
            {
                "id": r["id"],
                "date": r["hist_date"],
                "ville": r["hist_ville"],
                "statut": statut,
                "change": change,
                "avant": r["hist_detail"],
                "apres": nouveau,
                "alertes": " ; ".join(alerts),
            }
        )

    # ── Rapport ──
    par_statut: dict[str, list] = {}
    for x in resultats:
        par_statut.setdefault(x["statut"], []).append(x)

    print(f"\nBase : {DB_PATH}")
    print(f"Entrees hist_detail non vides : {len(resultats)}\n")
    print(f"{'statut':<10} {'total':>6} {'a modifier':>11}")
    print("-" * 30)
    for st in ("OK", "DOUTEUX", "DEFUSION", "MANUEL"):
        lot = par_statut.get(st, [])
        print(f"{st:<10} {len(lot):>6} {sum(1 for x in lot if x['change']):>11}")
    print()

    for st in ("OK", "DOUTEUX", "DEFUSION", "MANUEL"):
        if args.only and st != args.only:
            continue
        lot = [x for x in par_statut.get(st, []) if x["change"]]
        if not lot:
            continue
        print(f"\n=== {st} — {len(lot)} entrees a modifier ===")
        for x in lot[: args.limit]:
            print(f"\n  #{x['id']} {x['date']} {x['ville']}")
            print(f"    avant : {x['avant']}")
            print(f"    apres : {x['apres']}")
            if x["alertes"]:
                print(f"    ⚠ {x['alertes']}")
        if len(lot) > args.limit:
            print(f"\n  … {len(lot) - args.limit} autres (voir --csv)")

    if args.csv:
        with open(args.csv, "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(
                f, fieldnames=["id", "date", "ville", "statut", "change", "avant", "apres", "alertes"]
            )
            w.writeheader()
            w.writerows(resultats)
        print(f"\nRapport CSV ecrit : {args.csv}")

    # ── Ecriture ──
    if not args.apply:
        print("\n[dry-run] Rien n'a ete ecrit. Ajouter --apply pour appliquer.")
        return 0

    cibles = [
        x
        for x in resultats
        if x["change"]
        and x["statut"] != "MANUEL"
        and (not args.only or x["statut"] == args.only)
        and (not args.sans or args.sans not in x["alertes"])
        and (ids_cibles is None or x["id"] in ids_cibles)
    ]
    if not cibles:
        print("\nRien a appliquer.")
        return 0

    stamp = datetime.now().strftime("%y%m%d%H%M")
    backup = DB_PATH.with_name(f"{DB_PATH.stem}.backup-{stamp}-avant-detail.db")
    shutil.copy2(DB_PATH, backup)
    print(f"\nBackup : {backup}")

    con.executemany(
        "UPDATE historic SET hist_detail = ? WHERE id = ?",
        [(x["apres"], x["id"]) for x in cibles],
    )
    con.commit()
    print(f"{len(cibles)} entrees mises a jour.")
    print("Penser ensuite a : python3 scripts/export_dart.py")
    return 0


if __name__ == "__main__":
    sys.exit(main())
