#!/usr/bin/env python3
"""Normalize catalog neighborhoods so the region filter has one entry per place.

Idempotent: run it again after every catalog import.
"""
import json
import sys
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[1] / "Resources" / "Catalog" / "catalog.json"

ALIASES = {
    "Asa Sul,": "Asa Sul",
    "SHCS": "Asa Sul",
    "Aguas Claras Sul": "Águas Claras",
    "SCES": "Setor de Clubes Sul",
    "Setor de Clubes": "Setor de Clubes Sul",
    "Setor Norte": "Gama",
    "St. Hab Vicente Pires": "Vicente Pires",
    "St. Hab. Vicente Pires": "Vicente Pires",
    "Cruzeiro / Sudoeste / Octogonal": "Sudoeste",
    "Sudoeste/Octogonal": "Sudoeste",
    "Cond. Stylo - Noroeste": "Noroeste",
    "Setor Noroeste": "Noroeste",
    "Guará 2": "Guará",
    "Guará II": "Guará",
    "Taguatinga sul": "Taguatinga Sul",
    "Taguatinga Centro": "Taguatinga",
    "Samambaia Norte": "Samambaia",
    "Areal": "Águas Claras",
    "SHCN": "Asa Norte",
    "PARTE TÉRREO": "Asa Norte",
}

# Records whose source neighborhood is missing or too broad ("Plano Piloto"),
# resolved from the address.
OVERRIDES = {
    "duogourmet-brazolia-bar": "Asa Norte",
    "duogourmet-casa-de-marias": "Noroeste",
    "duogourmet-casa-do-strogonoff": "Asa Norte",
    "duogourmet-confraria-do-camarao-terraco-shopping": "Octogonal",
    "duogourmet-confraria-do-camarao-express-venancio-shopping-k84": "Asa Sul",
    "duogourmet-confraria-do-camarao-express-venancio-shopping": "Asa Sul",
    "duogourmet-raiz-caipira": "Asa Sul",
    "duogourmet-restaurante-faro": "Sudoeste",
    "duogourmet-happy-harry-308-norte": "Asa Norte",
    "duogourmet-hum-burguer--executivos--sudoeste": "Sudoeste",
    "duogourmet-marvin-burger-nya": "Asa Sul",
    "duogourmet-oli-confeitaria": "Asa Norte",
}


def main() -> int:
    restaurants = json.loads(CATALOG.read_text(encoding="utf-8"))
    changed = 0
    for restaurant in restaurants:
        current = restaurant.get("neighborhood")
        cleaned = OVERRIDES.get(restaurant["id"]) or ALIASES.get(current or "", current)
        if cleaned != current:
            restaurant["neighborhood"] = cleaned
            changed += 1
    CATALOG.write_text(json.dumps(restaurants, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Normalized {changed} neighborhoods")
    return 0


if __name__ == "__main__":
    sys.exit(main())
