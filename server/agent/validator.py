"""
agent/validator.py
Agent Claude : valide et enrichit une entrée Historic avant insertion en base.
"""

import json
import os
import re
from anthropic import Anthropic

_client = Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])

_SYSTEM = """
Tu es l'agent de validation des entrées de la base brocantes (cobroc).
Chaque entrée représente une visite à une brocante par PML ou FRA (collectionneurs).

Champs :
- hist_name     : "PML" ou "FRA" (visiteur)
- hist_date     : "AAAA-MM-JJ" (format ISO, ex: 2026-06-01)
- hist_good     : note 0–5
- hist_ville    : nom de la commune (MAJUSCULES)
- hist_code_postal : code postal français
- hist_adresse  : lieu précis ou voie
- hist_nb_expo  : nombre d'exposants estimé
- hist_pml_dep  : dépenses PML en euros
- hist_fra_dep  : dépenses FRA en euros
- hist_maison_dep : dépenses maison en euros
- hist_avis     : commentaire libre (peut être vide)
- hist_detail   : achats détaillés (peut être vide)

Pour chaque entrée tu dois :
1. Vérifier que hist_date est au format AAAA-MM-JJ et cohérente (date réelle).
2. Vérifier que hist_code_postal est plausible pour hist_ville (département cohérent).
3. Vérifier que hist_name est "PML" ou "FRA".
4. Détecter un doublon potentiel si existing_entries contient déjà la même
   (hist_ville + hist_date + hist_name).
5. Évaluer la qualité minimale du texte (pas de champs obligatoires vides si c'est
   une nouvelle entrée, pas un import).

Répond UNIQUEMENT en JSON (pas de markdown) :
{
  "approved": true | false,
  "notes": "explication courte en français",
  "suggestions": {
    "hist_ville": "valeur corrigée si besoin (sinon null)",
    "hist_date":  "date corrigée au format AAAA-MM-JJ si invalide (sinon null)",
    "hist_code_postal": null
  }
}

IMPORTANT : ne jamais modifier hist_avis, hist_detail ni hist_adresse — ce sont des textes libres saisis par l'utilisateur.
"""


def validate_entry(entry: dict, existing_entries: list[dict]) -> dict:
    """
    Valide `entry` contre `existing_entries` via Claude.
    Retourne {"approved": bool, "notes": str, "suggestions": dict}.
    """
    payload = {
        "new_entry": entry,
        "existing_entries_sample": existing_entries[:20],  # contexte limité
    }

    response = _client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=512,
        system=_SYSTEM,
        messages=[
            {
                "role": "user",
                "content": f"Valide cette entrée :\n{json.dumps(payload, ensure_ascii=False, indent=2)}",
            }
        ],
    )

    raw = response.content[0].text.strip()
    # Nettoyer un éventuel bloc ```json … ```
    raw = re.sub(r"^```(?:json)?\s*", "", raw)
    raw = re.sub(r"\s*```$", "", raw)

    try:
        result = json.loads(raw)
    except json.JSONDecodeError:
        result = {"approved": False, "notes": f"Réponse agent non parseable : {raw}", "suggestions": {}}

    return result
