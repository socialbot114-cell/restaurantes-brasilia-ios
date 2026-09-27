#!/usr/bin/env python3
"""Builds an image contact-sheet audit and HTML gallery for GitHub Actions."""
from __future__ import annotations

import argparse
import html
import json
import os
import re
import shutil
import sys
import textwrap
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterator

from PIL import Image, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "Resources" / "Catalog" / "catalog.json"
ASSETS = ROOT / "Resources" / "Assets.xcassets"
SHEET_COLUMNS = 6
SHEET_ROWS = 5
CELL_WIDTH = 250
CELL_HEIGHT = 190


def read_manifest_records(value: Any) -> Iterator[dict[str, Any]]:
    if isinstance(value, dict):
        if "exportedFileName" in value:
            yield value
        for child in value.values():
            yield from read_manifest_records(child)
    elif isinstance(value, list):
        for child in value:
            yield from read_manifest_records(child)


def safe_filename(value: str) -> str:
    value = Path(value).stem
    value = re.sub(r"[^A-Za-z0-9_-]+", "-", value).strip("-_")
    return value or "screenshot"


def export_screenshots(source_dir: Path, output_dir: Path) -> list[dict[str, str]]:
    screenshots_dir = output_dir / "screenshots"
    screenshots_dir.mkdir(parents=True, exist_ok=True)
    if not source_dir.exists():
        return []

    display_names: dict[Path, str] = {}
    manifest_files = sorted(source_dir.rglob("manifest.json"))
    for manifest_path in manifest_files:
        try:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        for item in read_manifest_records(manifest):
            exported_name = Path(str(item["exportedFileName"])).name
            candidates = [source_dir / exported_name]
            candidates.extend(source_dir.rglob(exported_name))
            source = next((candidate for candidate in candidates if candidate.is_file()), None)
            if source is None or source.suffix.lower() != ".png":
                continue
            display_names[source] = str(
                item.get("suggestedHumanReadableName")
                or item.get("name")
                or source.stem
            )

    png_files = sorted(path for path in source_dir.rglob("*.png") if path.is_file())
    copied: list[dict[str, str]] = []
    used_names: set[str] = set()
    for source in png_files:
        display = display_names.get(source, source.stem)
        stem = safe_filename(display)
        target_name = stem
        suffix = 2
        while target_name.lower() in used_names:
            target_name = f"{stem}-{suffix}"
            suffix += 1
        used_names.add(target_name.lower())
        destination = screenshots_dir / f"{target_name}.png"
        shutil.copy2(source, destination)
        copied.append({"name": display, "file": destination.relative_to(output_dir).as_posix()})
    return copied


def audit_and_load_photos() -> tuple[list[dict[str, Any]], dict[str, Any]]:
    records = json.loads(CATALOG.read_text(encoding="utf-8"))
    photos: list[dict[str, Any]] = []
    issues: list[str] = []

    for index, record in enumerate(records, start=1):
        restaurant = record.get("name") or record.get("id") or f"record-{index}"
        required = ("photo_asset", "photo_source_url", "photo_rights_status", "photo_attribution")
        missing = [field for field in required if not record.get(field)]
        if missing:
            issues.append(f"{restaurant}: missing photo metadata: {', '.join(missing)}")
            continue

        imageset = ASSETS / f"{record['photo_asset']}.imageset"
        contents_path = imageset / "Contents.json"
        if not contents_path.is_file():
            issues.append(f"{restaurant}: missing imageset Contents.json")
            continue
        try:
            contents = json.loads(contents_path.read_text(encoding="utf-8"))
            filename = contents["images"][0]["filename"]
            image_path = imageset / filename
            with Image.open(image_path) as source:
                source.load()
                image = ImageOps.exif_transpose(source).convert("RGB")
                width, height = image.size
        except (OSError, KeyError, IndexError, TypeError, json.JSONDecodeError) as error:
            issues.append(f"{restaurant}: image cannot be decoded: {error}")
            continue

        photos.append({
            "id": record["id"],
            "name": restaurant,
            "asset": record["photo_asset"],
            "file": image_path,
            "width": width,
            "height": height,
            "bytes": image_path.stat().st_size,
            "attribution": record["photo_attribution"],
            "source_url": record["photo_source_url"],
            "rights_status": record["photo_rights_status"],
        })

    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "catalog_records": len(records),
        "photos_decoded": len(photos),
        "attribution_counts": {
            name: sum(photo["attribution"] == name for photo in photos)
            for name in sorted({photo["attribution"] for photo in photos})
        },
        "photos": [
            {key: value for key, value in photo.items() if key != "file"}
            for photo in photos
        ],
        "issues": issues,
    }
    return photos, report


def create_contact_sheets(photos: list[dict[str, Any]], output_dir: Path) -> list[str]:
    sheet_dir = output_dir / "contact-sheets"
    sheet_dir.mkdir(parents=True, exist_ok=True)
    per_sheet = SHEET_COLUMNS * SHEET_ROWS
    paths: list[str] = []

    for start in range(0, len(photos), per_sheet):
        batch = photos[start:start + per_sheet]
        sheet_number = start // per_sheet + 1
        width = SHEET_COLUMNS * CELL_WIDTH
        height = 56 + SHEET_ROWS * CELL_HEIGHT
        canvas = Image.new("RGB", (width, height), "#f4f1eb")
        draw = ImageDraw.Draw(canvas)
        draw.text(
            (18, 16),
            f"Restaurant photo review · {start + 1}–{start + len(batch)} of {len(photos)}",
            fill="#213b32",
        )

        for offset, photo in enumerate(batch):
            column = offset % SHEET_COLUMNS
            row = offset // SHEET_COLUMNS
            x = column * CELL_WIDTH
            y = 56 + row * CELL_HEIGHT
            draw.rounded_rectangle(
                (x + 5, y + 5, x + CELL_WIDTH - 5, y + CELL_HEIGHT - 5),
                radius=12,
                fill="white",
                outline="#ddd8ce",
                width=1,
            )
            with Image.open(photo["file"]) as source:
                image = ImageOps.exif_transpose(source).convert("RGB")
                thumbnail = ImageOps.contain(image, (CELL_WIDTH - 24, 124))
            image_x = x + (CELL_WIDTH - thumbnail.width) // 2
            image_y = y + 10 + (124 - thumbnail.height) // 2
            canvas.paste(thumbnail, (image_x, image_y))

            label = f"{start + offset + 1:03d} · {photo['name']}"
            lines = textwrap.wrap(label, width=31, max_lines=2, placeholder="…")
            draw.multiline_text((x + 12, y + 140), "\n".join(lines), fill="#252a26", spacing=2)

        filename = f"photo-contact-sheet-{sheet_number:02d}.jpg"
        destination = sheet_dir / filename
        canvas.save(destination, "JPEG", quality=86, optimize=True)
        paths.append(destination.relative_to(output_dir).as_posix())
    return paths


def write_gallery(
    output_dir: Path,
    screenshots: list[dict[str, str]],
    contact_sheets: list[str],
    report: dict[str, Any],
) -> None:
    screenshot_cards = "\n".join(
        f'<article><a href="{html.escape(item["file"])}"><img loading="lazy" src="{html.escape(item["file"])}" alt="{html.escape(item["name"])}"></a><h3>{html.escape(item["name"])}</h3></article>'
        for item in screenshots
    ) or "<p>No UI screenshots were exported from the test result.</p>"
    contact_cards = "\n".join(
        f'<article><a href="{html.escape(path)}"><img loading="lazy" src="{html.escape(path)}" alt="{html.escape(Path(path).stem)}"></a><h3>{html.escape(Path(path).stem)}</h3></article>'
        for path in contact_sheets
    )
    issue_section = ""
    if report["issues"]:
        issue_items = "".join(f"<li>{html.escape(issue)}</li>" for issue in report["issues"])
        issue_section = f"<section><h2>Asset issues</h2><ul>{issue_items}</ul></section>"

    markup = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Restaurantes Brasília · Photo visual review</title>
  <style>
    :root {{ color-scheme: light; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; color: #213b32; background: #f4f1eb; }}
    body {{ margin: 0; padding: 28px; }}
    header {{ max-width: 1200px; margin: 0 auto 28px; }}
    h1 {{ margin: 0 0 8px; }}
    p {{ color: #5e655f; }}
    section {{ max-width: 1600px; margin: 30px auto; }}
    .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 16px; }}
    article {{ padding: 10px; background: white; border: 1px solid #ddd8ce; border-radius: 14px; }}
    article img {{ display: block; width: 100%; height: auto; border-radius: 8px; }}
    h3 {{ margin: 10px 2px 4px; font-size: 14px; overflow-wrap: anywhere; }}
    .sheets {{ grid-template-columns: repeat(auto-fit, minmax(450px, 1fr)); }}
  </style>
</head>
<body>
  <header>
    <h1>Restaurantes Brasília · Photo visual review</h1>
    <p>{len(screenshots)} simulator screenshots · {report['photos_decoded']}/{report['catalog_records']} photos decoded · generated {html.escape(report['generated_at'])}</p>
  </header>
  {issue_section}
  <section><h2>App screens</h2><div class="grid">{screenshot_cards}</div></section>
  <section><h2>Restaurant photo contact sheets</h2><div class="grid sheets">{contact_cards}</div></section>
</body>
</html>
"""
    (output_dir / "index.html").write_text(markup, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--screenshots-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--minimum-screenshots", type=int, default=0)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    photos, report = audit_and_load_photos()
    screenshots = export_screenshots(args.screenshots_dir, args.output_dir)
    contact_sheets = create_contact_sheets(photos, args.output_dir)
    report["screenshots"] = screenshots
    report["contact_sheets"] = contact_sheets
    report_path = args.output_dir / "photo-audit.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    write_gallery(args.output_dir, screenshots, contact_sheets, report)

    summary = (
        f"## Photo visual review\n\n"
        f"- Photos decoded: **{report['photos_decoded']}/{report['catalog_records']}**\n"
        f"- UI screenshots: **{len(screenshots)}**\n"
        f"- Contact sheets: **{len(contact_sheets)}**\n"
        f"- Gallery: `index.html` in the uploaded artifact\n"
    )
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as summary_file:
            summary_file.write(summary)
    else:
        print(summary)

    failures = list(report["issues"])
    if report["photos_decoded"] != report["catalog_records"]:
        failures.append("Not all catalog photos decoded successfully.")
    if len(screenshots) < args.minimum_screenshots:
        failures.append(
            f"Expected at least {args.minimum_screenshots} screenshots, got {len(screenshots)}."
        )
    if failures:
        print("\n".join(f"ERROR: {failure}" for failure in failures), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
