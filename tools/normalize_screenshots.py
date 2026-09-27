#!/usr/bin/env python3
"""Normalize iOS simulator screenshots to the App Store image dimensions."""
from __future__ import annotations

import argparse
import html
import json
import re
from pathlib import Path
from typing import Any, Iterator

from PIL import Image, ImageOps

SCREENSHOT_SIZES = {
    "iphone": (1242, 2688),
    "ipad": (2064, 2752),
}


def attachment_records(value: Any) -> Iterator[dict[str, Any]]:
    if isinstance(value, dict):
        if "exportedFileName" in value:
            yield value
        for child in value.values():
            yield from attachment_records(child)
    elif isinstance(value, list):
        for child in value:
            yield from attachment_records(child)


def safe_filename(value: str) -> str:
    stem = Path(value).stem
    stem = re.sub(r"[^A-Za-z0-9_-]+", "-", stem).strip("-_")
    return stem or "screenshot"


def locate_image(source_dir: Path, exported_name: str) -> Path | None:
    name = Path(exported_name).name
    direct = source_dir / name
    if direct.is_file():
        return direct
    return next((path for path in source_dir.rglob(name) if path.is_file()), None)


def save_screenshot(source: Path, destination: Path, size: tuple[int, int]) -> None:
    with Image.open(source) as original:
        image = ImageOps.exif_transpose(original).convert("RGB")
        background = image.getpixel((0, 0))
        normalized = ImageOps.pad(
            image,
            size,
            method=Image.Resampling.LANCZOS,
            color=background,
            centering=(0.5, 0.5),
        )
        if normalized.size != size:
            raise RuntimeError(f"Could not normalize {source.name} to {size}: got {normalized.size}")
        normalized.save(destination, format="PNG", optimize=True)


def write_gallery(output_dir: Path, device: str, size: tuple[int, int], screenshots: list[dict[str, str]]) -> None:
    cards = "\n".join(
        f'<article><a href="{html.escape(item["file"])}"><img src="{html.escape(item["file"])}" alt="{html.escape(item["name"])}"></a><h2>{html.escape(item["name"])}</h2><p>{size[0]} × {size[1]} px</p></article>'
        for item in screenshots
    ) or "<p>No PNG screenshots were exported.</p>"
    page = f"""<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Prints Restaurantes Brasília — {device}</title>
  <style>
    body {{ margin: 24px; color: #213b32; background: #f4f1eb; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }}
    main {{ max-width: 1400px; margin: auto; }}
    .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 18px; }}
    article {{ padding: 12px; background: white; border: 1px solid #ddd8ce; border-radius: 14px; }}
    img {{ display: block; width: 100%; height: auto; border-radius: 8px; }}
    h2 {{ font-size: 15px; overflow-wrap: anywhere; }}
    p {{ color: #69716c; }}
  </style>
</head>
<body><main><h1>Prints {html.escape(device)} · {size[0]} × {size[1]} px</h1><div class="grid">{cards}</div></main></body>
</html>
"""
    (output_dir / "index.html").write_text(page, encoding="utf-8")


def normalize_screenshots(input_dir: Path, output_dir: Path, device: str) -> list[dict[str, str]]:
    if device not in SCREENSHOT_SIZES:
        raise ValueError(f"Unknown device {device!r}; expected one of {', '.join(SCREENSHOT_SIZES)}")
    size = SCREENSHOT_SIZES[device]
    output_dir.mkdir(parents=True, exist_ok=True)

    manifest_path = next(iter(sorted(input_dir.rglob("manifest.json"))), None)
    if manifest_path:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    else:
        manifest = [{"attachments": []}]

    records = list(attachment_records(manifest))
    used_names: set[str] = set()
    processed_sources: set[Path] = set()
    output_records: list[dict[str, str]] = []

    def export(source: Path, suggested_name: str) -> str:
        stem = safe_filename(suggested_name)
        filename = stem
        suffix = 2
        while filename.lower() in used_names:
            filename = f"{stem}-{suffix}"
            suffix += 1
        used_names.add(filename.lower())
        destination_name = f"{filename}.png"
        save_screenshot(source, output_dir / destination_name, size)
        processed_sources.add(source.resolve())
        output_records.append({"name": suggested_name, "file": destination_name})
        return destination_name

    for record in records:
        exported_name = str(record.get("exportedFileName", ""))
        if not exported_name.lower().endswith(".png"):
            continue
        source = locate_image(input_dir, exported_name)
        if source is None:
            continue
        suggested = str(record.get("suggestedHumanReadableName") or Path(exported_name).name)
        record["exportedFileName"] = export(source, suggested)

    raw_pngs = sorted(path for path in input_dir.rglob("*.png") if path.is_file())
    fallback_records = []
    for source in raw_pngs:
        if source.resolve() in processed_sources:
            continue
        filename = export(source, source.name)
        fallback_records.append({"exportedFileName": filename, "suggestedHumanReadableName": source.name})

    if fallback_records:
        if not isinstance(manifest, list):
            manifest = [{"attachments": []}]
        manifest.append({"attachments": fallback_records})

    (output_dir / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    report = {
        "device": device,
        "width": size[0],
        "height": size[1],
        "screenshots": output_records,
    }
    (output_dir / "screenshot-dimensions.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    write_gallery(output_dir, device, size, output_records)
    print(f"Normalized {len(output_records)} {device} screenshots to {size[0]}×{size[1]} px in {output_dir}")
    return output_records


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--device", choices=sorted(SCREENSHOT_SIZES), required=True)
    args = parser.parse_args()
    normalize_screenshots(args.input_dir, args.output_dir, args.device)


if __name__ == "__main__":
    main()
