#!/usr/bin/env python3
"""Gera .imageset em JPEG para compatibilidade com o asset catalog do Xcode.

Para cada registro do catalogo com photo_asset, converte o WebP otimizado do
indice de midia em JPEG dentro de Resources/Assets.xcassets/<photo_asset>.imageset/
e escreve o Contents.json.
Pula assets ja autorizados manualmente (ex.: VeronaRistorante) e o proprio
VeronaRistorante, cujo arquivo e mantido a mao.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "Resources" / "Assets.xcassets"
CATALOG = ROOT / "Resources" / "Catalog" / "catalog.json"
DB_ROOT = Path("/home/richard/Documentos/db brasilia")
DEFAULT_INDEX = DB_ROOT / "restaurantes" / "data" / "media_index_webp.json"

SKIP = {"VeronaRistorante"}

CONTENTS = {
    "images": [{"filename": None, "idiom": "universal"}],
    "info": {"author": "xcode", "version": 1},
}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--index", type=Path, default=DEFAULT_INDEX)
    args = ap.parse_args()

    index = json.loads(args.index.read_text(encoding="utf-8"))
    by_slug = {m["slug"]: m for m in index}
    records = json.loads(CATALOG.read_text(encoding="utf-8"))

    written = skipped = missing = 0
    for rec in records:
        asset = rec.get("photo_asset")
        if not asset or asset in SKIP:
            skipped += 1
            continue
        media = by_slug.get(rec["id"])
        if not media:
            missing += 1
            continue
        src = DB_ROOT / media["arquivo"]
        if not src.is_file():
            missing += 1
            continue
        imageset = ASSETS / f"{asset}.imageset"
        imageset.mkdir(parents=True, exist_ok=True)
        dest = imageset / f"{asset}.jpg"
        with Image.open(src) as image:
            image = ImageOps.exif_transpose(image).convert("RGB")
            image.save(dest, "JPEG", quality=84, optimize=True, progressive=True)
        for stale in imageset.glob(f"{asset}.*"):
            if stale.suffix.lower() == ".webp":
                stale.unlink()
        contents = json.loads(json.dumps(CONTENTS))
        contents["images"][0]["filename"] = dest.name
        (imageset / "Contents.json").write_text(
            json.dumps(contents, indent=2) + "\n", encoding="utf-8"
        )
        written += 1

    print(f"[assets] escritos={written} pulados={skipped} sem-imagem={missing}")


if __name__ == "__main__":
    main()
