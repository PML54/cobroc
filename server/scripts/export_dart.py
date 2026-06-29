#!/usr/bin/env python3
"""
scripts/export_dart.py
Génère le contenu de historibroc.dart depuis la base SQLite.
Usage : python scripts/export_dart.py [--db PATH] [--out PATH]
"""

import sqlite3
import argparse
from datetime import datetime
from pathlib import Path

DEFAULT_DB  = Path(__file__).parent.parent / "db/historibroc.db"
DEFAULT_OUT = Path(__file__).parent.parent.parent / "lib/historibroc.dart"


def _escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def _to_dmy(date_str: str) -> str:
    """Convertit AAAA-MM-JJ → JJ/MM/AAAA pour Flutter. Laisse intact si déjà JJ/MM/AAAA."""
    if len(date_str) == 10 and date_str[4] == "-" and date_str[7] == "-":
        return date_str[8:10] + "/" + date_str[5:7] + "/" + date_str[0:4]
    return date_str


def generate_dart(db_path: Path) -> str:
    con = sqlite3.connect(db_path)
    con.row_factory = sqlite3.Row
    rows = con.execute("""
        SELECT h.*,
               COALESCE(l.parking, 0) AS parking,
               COALESCE(l.rues,    0) AS rues,
               COALESCE(l.stade,   0) AS stade,
               COALESCE(l.espace,  0) AS espace
        FROM historic h
        LEFT JOIN lieux l ON l.id = h.lieu_id
        WHERE h.validated = 1
        ORDER BY h.id
    """).fetchall()
    con.close()

    now = datetime.now().strftime("%y%m%d%H%M")
    n   = len(rows)

    lines = [
        "// lib/historibroc.dart",
        f"// Modified: {now}",
        "// Historic — liste des brocantes visitées",
        f"// CHANGEMENTS: (1) Export automatique depuis SQLite — {n} entrées validées",
        "",
        "import 'package:cobroc/diverspml.dart';",
        "import 'package:diacritic/diacritic.dart';",
        "",
        "class Historic {",
        '  String histName = "";',
        '  String histDate = "";',
        "  int histGood = 0;",
        '  String _histVille = "";',
        "  int histCodePostal = 0;",
        '  String histAdresse = "";',
        "  int histNbExpo = 0;",
        "  int histPmlDep = 0;",
        "  int histFraDep = 0;",
        "  int histMaisonDep = 0;",
        '  String histAvis = "";',
        '  String histDetail = "";',
        "  int histCode = 0;",
        "  DateTime histCheckDate = DateTime(2023, 07, 26);",
        '  String villeNormalized = "";',
        "  // Nouveaux champs (export enrichi)",
        '  String heureArrivee = "";',
        "  int pluie = 0;        // 0/1",
        "  int arriveeTard = 0;  // 0/1",
        "  int parking = 0;      // endroit du lieu, 0/1",
        "  int rues = 0;",
        "  int stade = 0;",
        "  int espace = 0;",
        "",
        "  Historic(",
        "      this.histName,",
        "      this.histDate,",
        "      this.histGood,",
        "      String histVille,",
        "      this.histCodePostal,",
        "      this.histAdresse,",
        "      this.histNbExpo,",
        "      this.histPmlDep,",
        "      this.histFraDep,",
        "      this.histMaisonDep,",
        "      this.histAvis,",
        "      this.histDetail, {",
        '      this.heureArrivee = "",',
        "      this.pluie = 0,",
        "      this.arriveeTard = 0,",
        "      this.parking = 0,",
        "      this.rues = 0,",
        "      this.stade = 0,",
        "      this.espace = 0,",
        "      }) {",
        "    BreakDate bri = BreakDate(histDate);",
        "    histCheckDate = bri.checkDate;",
        "    this.histVille =",
        "        histVille;",
        "  }",
        "",
        "  String get histVille => _histVille;",
        "",
        "  set histVille(String value) {",
        "    _histVille = value;",
        "    villeNormalized = normalizeString(value);",
        "  }",
        "",
        "  static String normalizeString(String str) {",
        "    String withoutDiacritics = removeDiacritics(str);",
        "    return withoutDiacritics.toUpperCase().replaceAll(RegExp('[^A-Z]'), '');",
        "  }",
        "",
        "  // Match exact OU préfixe : \"ERAGNY\" matche \"ERAGNYSUROISE\" et vice-versa",
        "  static bool matchesVille(String histVille, String searchVille) {",
        "    final hn = normalizeString(histVille);",
        "    final sn = normalizeString(searchVille);",
        "    if (hn == sn) return true;",
        "    if (hn.length < 4 || sn.length < 4) return false;",
        "    return hn.startsWith(sn) || sn.startsWith(hn);",
        "  }",
        "}",
        "",
        "final listHistoric = [",
    ]

    for row in rows:
        name    = _escape(row["hist_name"])
        date    = _escape(_to_dmy(row["hist_date"]))
        good    = row["hist_good"]
        ville   = _escape(row["hist_ville"])
        cp      = row["hist_code_postal"]
        adresse = _escape(row["hist_adresse"])
        expo    = row["hist_nb_expo"]
        pml     = row["hist_pml_dep"]
        fra     = row["hist_fra_dep"]
        maison  = row["hist_maison_dep"]
        avis    = _escape(row["hist_avis"])
        detail  = _escape(row["hist_detail"])

        # Champs enrichis : émis uniquement si non-défaut (lignes minimales)
        extras = []
        heure = (row["heure_arrivee"] or "").strip()
        if heure:
            extras.append(f'heureArrivee: "{_escape(heure)}"')
        if row["pluie"]:
            extras.append("pluie: 1")
        if row["arrivee_tard"]:
            extras.append("arriveeTard: 1")
        if row["parking"]:
            extras.append("parking: 1")
        if row["rues"]:
            extras.append("rues: 1")
        if row["stade"]:
            extras.append("stade: 1")
        if row["espace"]:
            extras.append("espace: 1")
        extra_str = (", " + ", ".join(extras)) if extras else ""

        lines.append(
            f'  Historic("{name}", "{date}", {good}, "{ville}", {cp}, '
            f'"{adresse}", {expo}, {pml}, {fra}, {maison}, "{avis}", "{detail}"{extra_str}),'
        )

    lines.append("];")
    lines.append("")
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db",  default=str(DEFAULT_DB))
    ap.add_argument("--out", default=str(DEFAULT_OUT))
    ap.add_argument("--print", action="store_true", help="Affiche sur stdout sans écrire")
    args = ap.parse_args()

    content = generate_dart(Path(args.db))

    if args.print:
        print(content)
        return

    out = Path(args.out)
    out.write_text(content, encoding="utf-8")
    n = content.count("Historic(")
    print(f"[OK] {n} entrées exportées vers {out}")


if __name__ == "__main__":
    main()
