#!/usr/bin/env python3
"""
datatourisme_brocantes.py  —  cobroc-server

Récupère le flux open data DATAtourisme (Licence Ouverte) configuré pour le
projet et en extrait la liste des brocantes / vide-greniers sous la forme
« date + ville », triée par date. Sert à compléter les lieux absents de
brocabrac.fr — usage personnel, source officielle (pas de scraping).

Source : flux diffuseur DATAtourisme
  URL = https://diffuseur.datatourisme.fr/webservice/<FLOW_ID>/<APP_KEY>
  FLOW_ID + APP_KEY lus dans server/.env (APP_KEY = secret, jamais versionné).

Le webservice renvoie une archive ZIP de fichiers JSON-LD (un POI par fichier).
La structure exacte des objets varie : on extrait défensivement le libellé,
la commune, le code postal et la/les date(s). Utiliser --inspect pour afficher
la structure brute des premiers objets et calibrer si besoin.

Dépendances : stdlib (urllib, zipfile, json) + python-dotenv (déjà installé).

Usage (depuis server/) :
  .venv/bin/python scripts/datatourisme_brocantes.py            # liste à venir
  .venv/bin/python scripts/datatourisme_brocantes.py --days 30  # 30 prochains jours
  .venv/bin/python scripts/datatourisme_brocantes.py --all      # sans filtre de date
  .venv/bin/python scripts/datatourisme_brocantes.py --csv out.csv
  .venv/bin/python scripts/datatourisme_brocantes.py --inspect 3 # debug structure
  .venv/bin/python scripts/datatourisme_brocantes.py --debug-http # voir le corps d'une réponse en erreur (503…)
"""

import argparse
import csv
import io
import json
import os
import re
import sys
import unicodedata
import urllib.request
import zipfile
from datetime import date, datetime
from pathlib import Path

from dotenv import load_dotenv

WEBSERVICE = "https://diffuseur.datatourisme.fr/webservice/{flow_id}/{app_key}"

# Mots-clés identifiant une brocante / vide-grenier parmi les « Fête et manifestation ».
BROC_KEYWORDS = (
    "brocante", "vide-grenier", "vide grenier", "videgrenier",
    "vide-greniers", "puces", "deballage", "marche aux puces",
)


# ── Helpers ──────────────────────────────────────────────────────────────────

def _noaccent(s: str) -> str:
    """Minuscule sans accents — pour comparaison de mots-clés."""
    return (
        unicodedata.normalize("NFD", s or "")
        .encode("ascii", "ignore")
        .decode("ascii")
        .lower()
    )


def _load_credentials() -> tuple[str, str]:
    """Lit FLOW_ID + APP_KEY depuis server/.env. APP_KEY reste secret."""
    load_dotenv()
    flow_id = (os.getenv("DATATOURISME_FLOW_ID") or "").strip()
    app_key = (os.getenv("DATATOURISME_APP_KEY") or "").strip()
    if not flow_id or flow_id == "VOTRE_ID_DE_FLUX":
        sys.exit("✗ DATATOURISME_FLOW_ID manquant dans .env")
    if not app_key or app_key == "VOTRE_CLE_APPLICATION":
        sys.exit("✗ DATATOURISME_APP_KEY manquant dans .env (clé de l'application cobroc)")
    return flow_id, app_key


def _dump_http_error(e: "urllib.error.HTTPError") -> None:
    """Affiche le statut, les en-têtes et le corps brut d'une réponse HTTP en erreur.

    DATAtourisme renvoie souvent un message texte (ou JSON) expliquant *pourquoi*
    l'archive n'est pas servie (flux en cours de génération, vide, non publié…).
    """
    print(f"── DEBUG HTTP {e.code} {e.reason} ──", file=sys.stderr)
    try:
        for k, v in e.headers.items():
            print(f"{k}: {v}", file=sys.stderr)
    except Exception:
        pass
    print("── corps de la réponse ──", file=sys.stderr)
    try:
        body = e.read()
        text = body.decode("utf-8", "replace") if body else "(vide)"
        print(text.strip() or "(vide)", file=sys.stderr)
    except Exception as ex:
        print(f"(impossible de lire le corps : {ex})", file=sys.stderr)
    print("─" * 30, file=sys.stderr)


def _download_zip(flow_id: str, app_key: str, debug_http: bool = False) -> zipfile.ZipFile:
    """Télécharge l'archive du flux et la renvoie en ZipFile (en mémoire)."""
    url = WEBSERVICE.format(flow_id=flow_id, app_key=app_key)
    req = urllib.request.Request(url, headers={"User-Agent": "cobroc-perso/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            data = resp.read()
    except urllib.error.HTTPError as e:
        if debug_http:
            _dump_http_error(e)
        if e.code == 503:
            sys.exit(
                "⏳ 503 — archive du flux non disponible. Cause habituelle (DATAtourisme) : "
                "génération du flux non programmée, ou désactivée après une période "
                "d'inactivité. À (ré)activer/programmer sur le portail diffuseur "
                "(diffuseur.datatourisme.fr). Relancer avec --debug-http pour le message exact."
            )
        if e.code == 404:
            sys.exit(
                "✗ 404 — flux introuvable : vérifier DATATOURISME_FLOW_ID et "
                "DATATOURISME_APP_KEY dans .env (ID de flux / clé d'application)."
            )
        if e.code in (401, 403):
            sys.exit(f"✗ {e.code} — accès refusé : la clé d'application (.env) semble invalide.")
        sys.exit(f"✗ Erreur HTTP {e.code} en téléchargeant le flux.")
    except urllib.error.URLError as e:
        sys.exit(f"✗ Erreur réseau : {e.reason}")
    try:
        return zipfile.ZipFile(io.BytesIO(data))
    except zipfile.BadZipFile:
        sys.exit("✗ La réponse n'est pas un ZIP (flux pas encore prêt ?).")


def _iter_pois(zf: zipfile.ZipFile):
    """Itère chaque objet POI (dict JSON-LD) de l'archive."""
    for name in zf.namelist():
        if not name.endswith(".json"):
            continue
        base = name.rsplit("/", 1)[-1].lower()
        if base in ("index.json", "context.json", "context.jsonld"):
            continue
        try:
            obj = json.loads(zf.read(name))
        except (json.JSONDecodeError, UnicodeDecodeError):
            continue
        # Un fichier peut contenir un objet direct ou un @graph (liste)
        if isinstance(obj, dict) and "@graph" in obj and isinstance(obj["@graph"], list):
            yield from (g for g in obj["@graph"] if isinstance(g, dict))
        elif isinstance(obj, list):
            yield from (g for g in obj if isinstance(g, dict))
        elif isinstance(obj, dict):
            yield obj


# ── Extraction de champs (défensive : noms de propriétés variables) ───────────

def _label(poi: dict) -> str:
    """Libellé fr du POI (rdfs:label / schema:name, multilingue ou non)."""
    for key in ("rdfs:label", "label", "schema:name", "name"):
        val = poi.get(key)
        txt = _pick_lang(val)
        if txt:
            return txt
    return ""


def _pick_lang(val, lang: str = "fr") -> str:
    """Extrait une valeur texte d'un champ JSON-LD (str, {@value}, ou multilingue)."""
    if val is None:
        return ""
    if isinstance(val, str):
        return val.strip()
    if isinstance(val, dict):
        # { "fr": ["..."] } ou { "@value": "..." }
        if lang in val:
            return _pick_lang(val[lang])
        if "@value" in val:
            return str(val["@value"]).strip()
        # premier sous-champ exploitable
        for v in val.values():
            t = _pick_lang(v)
            if t:
                return t
        return ""
    if isinstance(val, list):
        for item in val:
            t = _pick_lang(item)
            if t:
                return t
    return ""


def _find_first(obj, keys: tuple, _depth: int = 0):
    """Recherche récursive de la 1re valeur pour l'une des clés (insensible au préfixe)."""
    if _depth > 6 or obj is None:
        return None
    if isinstance(obj, dict):
        for k, v in obj.items():
            short = k.split(":")[-1]
            if k in keys or short in keys:
                return v
        for v in obj.values():
            r = _find_first(v, keys, _depth + 1)
            if r is not None:
                return r
    elif isinstance(obj, list):
        for item in obj:
            r = _find_first(item, keys, _depth + 1)
            if r is not None:
                return r
    return None


def _ville_cp(poi: dict) -> tuple[str, str]:
    """Commune + code postal via isLocatedAt → address."""
    loc = poi.get("isLocatedAt") or poi.get("schema:address") or poi
    ville = _pick_lang(_find_first(loc, ("addressLocality",)))
    cp = _pick_lang(_find_first(loc, ("postalCode",)))
    return ville.upper(), cp


_DATE_RE = re.compile(r"(\d{4})-(\d{2})-(\d{2})")


def _dates(poi: dict) -> list[date]:
    """Toutes les dates de début trouvées (startDate / hasBeginning / takesPlaceAt…)."""
    found: set[date] = set()

    def collect(node, _depth=0):
        if _depth > 6 or node is None:
            return
        if isinstance(node, str):
            m = _DATE_RE.search(node)
            if m:
                try:
                    found.add(date(int(m[1]), int(m[2]), int(m[3])))
                except ValueError:
                    pass
        elif isinstance(node, dict):
            for k, v in node.items():
                short = k.split(":")[-1]
                if short in ("startDate", "hasBeginning", "beginning",
                             "takesPlaceAt", "dateDebut", "@value"):
                    collect(v, _depth + 1)
        elif isinstance(node, list):
            for item in node:
                collect(item, _depth + 1)

    collect(poi.get("takesPlaceAt"))
    for key in ("schema:startDate", "startDate", "hasBeginning"):
        collect(poi.get(key))
    return sorted(found)


def _is_brocante(poi: dict) -> bool:
    """Vrai si le POI ressemble à une brocante/vide-grenier (label + types + thèmes)."""
    haystack = _noaccent(_label(poi))
    # types et thèmes éventuels
    for extra in (poi.get("@type"), _find_first(poi, ("hasTheme", "theme"))):
        haystack += " " + _noaccent(json.dumps(extra, ensure_ascii=False)) if extra else ""
    return any(kw in haystack for kw in BROC_KEYWORDS)


# ── Modes ─────────────────────────────────────────────────────────────────────

def run_inspect(zf: zipfile.ZipFile, n: int):
    """Affiche la structure brute des n premiers objets — pour calibrer l'extraction."""
    files = [x for x in zf.namelist() if x.endswith(".json")]
    print(f"# Archive : {len(zf.namelist())} fichiers, {len(files)} .json\n")
    shown = 0
    for poi in _iter_pois(zf):
        print(json.dumps(poi, ensure_ascii=False, indent=2)[:3000])
        print("-" * 70)
        shown += 1
        if shown >= n:
            break
    if not shown:
        print("Aucun objet JSON-LD lisible dans l'archive.")


def run_list(zf: zipfile.ZipFile, days: int | None, show_all: bool, csv_path: str | None):
    """Collecte, filtre par date, trie et affiche/exporte les brocantes."""
    from datetime import timedelta

    today = date.today()
    rows = []
    total = brocs = 0
    for poi in _iter_pois(zf):
        total += 1
        if not _is_brocante(poi):
            continue
        brocs += 1
        ville, cp = _ville_cp(poi)
        label = _label(poi)
        for d in _dates(poi):
            rows.append((d, cp, ville, label))

    # Filtre de date : --all = tout ; --days N = N prochains jours ; défaut = à venir.
    if not show_all:
        if days is not None:
            limit = today + timedelta(days=days)
            rows = [r for r in rows if today <= r[0] <= limit]
        else:
            rows = [r for r in rows if r[0] >= today]

    rows.sort(key=lambda r: (r[0], r[2]))

    if csv_path:
        with open(csv_path, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(["date", "code_postal", "ville", "titre"])
            for d, cp, ville, titre in rows:
                w.writerow([d.isoformat(), cp, ville, titre])
        print(f"✓ {len(rows)} ligne(s) écrites dans {csv_path}")
    else:
        for d, cp, ville, titre in rows:
            print(f"{d.isoformat()}  {cp:<6} {ville:<28} {titre}")
        print(f"\n# {len(rows)} brocante(s) listées "
              f"({brocs} brocantes détectées sur {total} POI dans le flux)")


# ── Entrée ─────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(description="Liste date+ville des brocantes (flux DATAtourisme).")
    ap.add_argument("--days", type=int, default=None,
                    help="Ne garder que les N prochains jours.")
    ap.add_argument("--all", action="store_true",
                    help="Toutes les dates (y compris passées), sans filtre.")
    ap.add_argument("--csv", metavar="PATH", help="Exporter en CSV au lieu d'afficher.")
    ap.add_argument("--inspect", type=int, metavar="N",
                    help="Afficher la structure brute des N premiers objets (debug).")
    ap.add_argument("--debug-http", action="store_true",
                    help="En cas d'erreur HTTP (503…), afficher en-têtes + corps de la réponse.")
    args = ap.parse_args()

    flow_id, app_key = _load_credentials()
    zf = _download_zip(flow_id, app_key, debug_http=args.debug_http)

    if args.inspect:
        run_inspect(zf, args.inspect)
    else:
        run_list(zf, args.days, args.all, args.csv)


if __name__ == "__main__":
    main()
