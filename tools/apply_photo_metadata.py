#!/usr/bin/env python3
"""Preenche os metadados de foto no catalogo iOS a partir do indice de midia.

Le o media_index.json (ou media_index_webp.json) do repositorio db brasilia e
grava photo_asset / photo_source_url / photo_rights_status em cada registro de
Resources/Catalog/catalog.json cujo id exista no indice.

O nome do asset segue o padrao usado pelo app Android:
  duogourmet-313-drink-bar -> Duo_313_Drink_Bar
Assim o mesmo slug gera o mesmo nome nos dois apps.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Resources" / "Catalog" / "catalog.json"
DEFAULT_INDEX = Path("/home/richard/Documentos/db brasilia/restaurantes/data/media_index.json")

SOURCE_ATTRIBUTION = "Duo Gourmet"
RIGHTS_STATUS = "source-attributed-duo-gourmet"


def asset_name(slug: str) -> str:
    stem = slug.removeprefix("duogourmet-")
    stem = re.sub(r"[^0-9A-Za-z]+", "_", stem).strip("_")
    parts = [p for p in stem.split("_") if p]
    return "Duo_" + "_".join(p[:1].upper() + p[1:] for p in parts)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--index", type=Path, default=DEFAULT_INDEX)
    ap.add_argument("--attribution", default=SOURCE_ATTRIBUTION)
    ap.add_argument("--rights-status", default=RIGHTS_STATUS)
    args = ap.parse_args()

    index = json.loads(args.index.read_text(encoding="utf-8"))
    by_slug = {m["slug"]: m for m in index}

    records = json.loads(CATALOG.read_text(encoding="utf-8"))
    updated = missing = preserved = 0
    for rec in records:
        if rec.get("photo_rights_status") == "user-confirmed-authorized":
            preserved += 1
            continue
        media = by_slug.get(rec["id"])
        if not media:
            missing += 1
            continue
        rec["photo_asset"] = asset_name(rec["id"])
        rec["photo_source_url"] = media.get("url") or media.get("url_origem")
        rec["photo_rights_status"] = args.rights_status
        rec["photo_attribution"] = args.attribution
        updated += 1

    CATALOG.write_text(
        json.dumps(records, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"[photos] atualizados={updated} preservados={preserved} "
          f"sem-midia={missing} total={len(records)}")


if __name__ == "__main__":
    main()