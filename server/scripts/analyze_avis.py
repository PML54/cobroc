"""
scripts/analyze_avis.py
Analyse tous les commentaires hist_avis via Claude et en extrait des questions pertinentes.
Usage : python scripts/analyze_avis.py
"""

import os
import sqlite3
import textwrap
from anthropic import Anthropic
from dotenv import load_dotenv

load_dotenv()

DB_PATH = os.getenv("DB_PATH", "./db/historibroc.db")
client = Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
MODEL = "claude-opus-4-8"

BATCH_SIZE = 300  # commentaires par lot (≈ 40 k tokens)


def load_avis() -> list[str]:
    con = sqlite3.connect(DB_PATH)
    rows = con.execute(
        "SELECT hist_avis FROM historic WHERE hist_avis IS NOT NULL AND hist_avis != '' ORDER BY hist_date"
    ).fetchall()
    con.close()
    return [r[0].strip() for r in rows if r[0].strip()]


def analyze_batch(batch: list[str], batch_num: int, total_batches: int) -> str:
    numbered = "\n".join(f"{i+1}. {c}" for i, c in enumerate(batch))
    prompt = f"""\
Voici {len(batch)} commentaires de visiteurs de brocantes (lot {batch_num}/{total_batches}).
Ces notes de terrain décrivent des visites réelles à des marchés aux puces en France.

COMMENTAIRES :
{numbered}

Analyse ce lot et identifie :
1. Les THÈMES récurrents (ex : heure d'arrivée, qualité des exposants, parking, météo…)
2. Les OBSERVATIONS pratiques notables (conseils, astuces, mises en garde)
3. Les PATTERNS inhabituels ou surprenants

Réponds en français, de manière synthétique, en listes à puces. Pas de intro ni de conclusion."""

    resp = client.messages.create(
        model=MODEL,
        max_tokens=1024,
        messages=[{"role": "user", "content": prompt}],
    )
    return resp.content[0].text.strip()


def synthesize_questions(themes_per_batch: list[str]) -> str:
    all_themes = "\n\n---\n\n".join(
        f"LOT {i+1} :\n{t}" for i, t in enumerate(themes_per_batch)
    )
    prompt = f"""\
Tu as analysé {len(themes_per_batch)} lots de commentaires de visites de brocantes.
Voici les thèmes et observations extraits de chaque lot :

{all_themes}

À partir de cette synthèse, génère une liste de QUESTIONS PERTINENTES qu'on pourrait \
explorer avec cette base de données. Ces questions doivent être :
- Concrètes et répondables avec les données disponibles
- Utiles pour mieux comprendre les habitudes de visite (heure, fréquence, villes…)
- Utiles pour identifier les meilleures brocantes (note, dépenses, exposants…)
- Utiles pour détecter des patterns saisonniers ou géographiques
- Classées par catégorie (Pratique, Qualité, Géographie, Temporel, Comportemental…)

Pour chaque question, indique brièvement quelle requête SQL ou quel type d'analyse \
permettrait d'y répondre.

Réponds en français, structuré et clair."""

    resp = client.messages.create(
        model=MODEL,
        max_tokens=2048,
        messages=[{"role": "user", "content": prompt}],
    )
    return resp.content[0].text.strip()


def main():
    print("Chargement des commentaires…")
    avis = load_avis()
    print(f"  → {len(avis)} commentaires trouvés")

    batches = [avis[i : i + BATCH_SIZE] for i in range(0, len(avis), BATCH_SIZE)]
    total = len(batches)
    print(f"  → {total} lots de {BATCH_SIZE}")

    themes_per_batch = []
    for i, batch in enumerate(batches):
        print(f"\nAnalyse lot {i+1}/{total} ({len(batch)} commentaires)…")
        themes = analyze_batch(batch, i + 1, total)
        themes_per_batch.append(themes)
        print(textwrap.indent(themes[:300] + "…", "  "))

    print("\n" + "=" * 60)
    print("SYNTHÈSE — GÉNÉRATION DES QUESTIONS PERTINENTES")
    print("=" * 60 + "\n")
    questions = synthesize_questions(themes_per_batch)
    print(questions)

    # Sauvegarde
    out = "scripts/avis_questions.md"
    with open(out, "w", encoding="utf-8") as f:
        f.write("# Questions pertinentes extraites de hist_avis\n\n")
        f.write(f"_Analyse de {len(avis)} commentaires en {total} lots._\n\n")
        f.write("---\n\n")
        f.write(questions)
        f.write("\n\n---\n\n## Thèmes par lot\n\n")
        for i, t in enumerate(themes_per_batch):
            f.write(f"### Lot {i+1}\n\n{t}\n\n")
    print(f"\nRapport sauvegardé dans {out}")


if __name__ == "__main__":
    main()
