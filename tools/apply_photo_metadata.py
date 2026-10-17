#!/usr/bin/env python3
"""Remove photo metadata unless redistribution permission is documented.

The shared media index records photo sources, not redistribution rights.
Attribution alone is not permission, so this tool must never create photo
metadata from that index. An authorized photo must be added to the iOS catalog
with its permission record after written authorization is documented.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Resources" / "Catalog" / "catalog.json"

def main() -> None:
    records = json.loads(CATALOG.read_text(encoding="utf-8"))
    removed = preserved = 0
    for rec in records:
        if rec.get("photo_rights_status") == "user-confirmed-authorized":
            preserved += 1
            continue
        for field in ("photo_asset", "photo_source_url", "photo_rights_status", "photo_attribution"):
            if rec.pop(field, None) is not None:
                removed += 1

    CATALOG.write_text(
        json.dumps(records, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"[photos] campos-sem-autorizacao-removidos={removed} "
          f"registros-autorizados-preservados={preserved} total={len(records)}")


if __name__ == "__main__":
    main()
