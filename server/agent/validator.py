"""
agent/validator.py
Agent Claude : valide et enrichit une entrée Historic avant insertion en base.
"""

import json
import os
import re
import unicodedata
from anthropic import Anthropic

_client = Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])


def _norm_ville(v: str) -> str:
    """Normalise une ville pour comparaison : majuscules, sans accents, sans espaces de bord."""
    v = (v or "").strip().upper()
    return "".join(c for c in unicodedata.normalize("NFD", v) if unicodedata.category(c) != "Mn")


def _is_true_duplicate(entry: dict, existing_entries: list[dict]) -> bool:
    """
    Vrai doublon = une entrée existante avec le MÊME visiteur (hist_name),
    la MÊME date et la MÊME ville. C'est la contrainte d'unicité réelle
    (hist_ville + hist_name + hist_date). Deux visiteurs différents (PML/FRA)
    à la même brocante ne sont PAS un doublon.
    """
    name  = (entry.get("hist_name") or "").strip().upper()
    date  = (entry.get("hist_date") or "").strip()
    ville = _norm_ville(entry.get("hist_ville"))
    for e in existing_entries:
        if ((e.get("hist_name") or "").strip().upper() == name
                and (e.get("hist_date") or "").strip() == date
                and _norm_ville(e.get("hist_ville")) == ville):
            return True
    return False

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
4. NE PAS juger les doublons : la détection de doublon est faite de façon
   déterministe par le système (même visiteur + même ville + même date).
   IMPORTANT : PML et FRA sont DEUX collectionneurs DIFFÉRENTS. Il est NORMAL
   et légitime qu'ils aient CHACUN une entrée pour la même ville le même jour
   (ils visitent souvent ensemble). N'utilise JAMAIS "doublon" comme motif de refus.
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

    # --- Détection de doublon DÉTERMINISTE (fait autorité, pas le LLM) ---
    true_dup     = _is_true_duplicate(entry, existing_entries)
    llm_approved = bool(result.get("approved"))
    note_txt     = (result.get("notes") or "").lower()

    if not true_dup and not llm_approved and ("doublon" in note_txt or "duplicate" in note_txt):
        # Le LLM a refusé à tort pour un doublon inexistant (ex. visite PML/FRA
        # conjointe) → on ré-approuve : les doublons ne sont plus de son ressort.
        llm_approved = True
        result["notes"] = "Approuvé (faux doublon ignoré). " + (result.get("notes") or "")

    result["approved"] = llm_approved and not true_dup
    if true_dup:
        result["notes"] = (
            f"Doublon réel : une entrée {entry.get('hist_name')} existe déjà pour "
            f"{entry.get('hist_ville')} le {entry.get('hist_date')}."
        )

    return result
