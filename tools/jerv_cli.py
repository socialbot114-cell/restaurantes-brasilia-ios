#!/usr/bin/env python3
"""JERV deterministic app factory commands."""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

import yaml

ROOT = Path(__file__).resolve().parent
TEMPLATE = ROOT / "templates" / "ios-swiftui-directory"
SECRET_PARTS = (".p8", ".cer", ".key", ".mobileprovision", ".jks", ".keystore")
BUNDLE_RE = re.compile(r"^[a-z][a-z0-9]*(?:\.[a-z0-9]+)+$")


def fail(message: str, errors: list[str]) -> None:
    errors.append(message)


def load_manifest(path: Path) -> tuple[dict[str, Any], Path]:
    if not path.is_file():
        raise SystemExit(f"manifest not found: {path}")
    try:
        value = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError as exc:
        raise SystemExit(f"invalid YAML: {exc}") from exc
    if not isinstance(value, dict):
        raise SystemExit("manifest must contain a mapping")
    return value, path.parent


def validate_manifest(manifest: dict[str, Any], base: Path) -> list[str]:
    errors: list[str] = []
    required = ("name", "product_name", "bundle_id", "sku", "app_store_id", "platform", "template")
    for key in required:
        if not manifest.get(key):
            fail(f"missing required field: {key}", errors)
    bundle = str(manifest.get("bundle_id", ""))
    if bundle and (not BUNDLE_RE.fullmatch(bundle) or any(c.isupper() for c in bundle)):
        fail(f"bundle_id must be lowercase reverse-DNS: {bundle}", errors)
    app_store_id = str(manifest.get("app_store_id", ""))
    if app_store_id and not app_store_id.isdigit():
        fail("app_store_id must be numeric", errors)
    if manifest.get("platform") != "ios":
        fail("this release contract currently supports platform: ios", errors)
    if manifest.get("template") != "ios-swiftui-directory":
        fail(f"unknown template: {manifest.get('template')}", errors)

    catalog = manifest.get("catalog") or {}
    catalog_path = catalog.get("path") if isinstance(catalog, dict) else None
    if catalog_path:
        path = base / catalog_path
        if not path.is_file():
            fail(f"catalog not found: {path}", errors)
    privacy = manifest.get("privacy_manifest")
    if privacy:
        path = base / privacy
        if not path.is_file():
            fail(f"Privacy Manifest not found: {path}", errors)
    release = manifest.get("release") or {}
    if not release.get("scheme"):
        fail("release.scheme is required", errors)
    return errors


def validate_catalog(manifest: dict[str, Any], base: Path, release: bool = False) -> list[str]:
    catalog = manifest.get("catalog") or {}
    if not isinstance(catalog, dict) or not catalog.get("path"):
        return []
    path = base / catalog["path"]
    if not path.is_file():
        return []
    errors: list[str] = []
    unverified = 0
    try:
        records = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"catalog is not valid JSON: {exc}"]
    if not isinstance(records, list):
        return ["catalog root must be an array"]
    required = catalog.get("required_fields", ["id", "name", "source", "last_verified"])
    ids: set[str] = set()
    for index, record in enumerate(records):
        if not isinstance(record, dict):
            fail(f"catalog record {index} must be an object", errors)
            continue
        for field in required:
            if record.get(field) in (None, "", []):
                fail(f"catalog record {index} missing {field}", errors)
        if release and record.get("data_status") not in (None, "verified"):
            unverified += 1
        record_id = str(record.get("id", ""))
        if record_id in ids:
            fail(f"duplicate catalog id: {record_id}", errors)
        ids.add(record_id)
    if not records:
        fail("catalog must not be empty", errors)
    if unverified:
        fail(f"catalog contains {unverified} records not marked data_status: verified", errors)
    return errors


def scan_secrets(base: Path) -> list[str]:
    errors: list[str] = []
    ignored = {".git", ".gradle", "build", "DerivedData", ".venv"}
    for path in base.rglob("*"):
        if any(part in ignored for part in path.parts):
            continue
        if path.is_file() and path.name.lower() not in {".gitignore"}:
            if path.suffix.lower() in SECRET_PARTS or path.name in {"keystore.properties", "local.properties"}:
                fail(f"secret-like file present in project tree: {path.relative_to(base)}", errors)
    return errors


def run_validation(manifest_path: Path, release: bool = False) -> int:
    manifest, base = load_manifest(manifest_path)
    errors = validate_manifest(manifest, base)
    errors.extend(validate_catalog(manifest, base, release=release))
    errors.extend(scan_secrets(base))
    if release and manifest.get("release", {}).get("artifact_name") in (None, ""):
        errors.append("release.artifact_name is required for release")
    if errors:
        print("JERV FAILED")
        for error in errors:
            print(f"- {error}")
        return 1
    print(f"JERV OK: {manifest['name']} ({manifest['bundle_id']})")
    return 0


def audit(manifest_path: Path) -> int:
    manifest, base = load_manifest(manifest_path)
    findings = []
    for error in validate_manifest(manifest, base) + validate_catalog(manifest, base) + scan_secrets(base):
        severity = "blocker" if any(word in error for word in ("secret", "bundle_id", "Privacy Manifest")) else "error"
        findings.append({"severity": severity, "message": error})
    report_dir = base / "reports" / "jerv"
    report_dir.mkdir(parents=True, exist_ok=True)
    output = {"app": manifest.get("name"), "bundle_id": manifest.get("bundle_id"), "findings": findings}
    (report_dir / "audit.json").write_text(json.dumps(output, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(output, indent=2, ensure_ascii=False))
    return 1 if findings else 0


def init_project(destination: Path, manifest_path: Path) -> int:
    manifest, _ = load_manifest(manifest_path)
    if destination.exists() and any(destination.iterdir()):
        raise SystemExit(f"destination is not empty: {destination}")
    destination.mkdir(parents=True, exist_ok=True)
    for source in TEMPLATE.rglob("*"):
        relative = source.relative_to(TEMPLATE)
        target = destination / relative
        if source.is_dir():
            target.mkdir(parents=True, exist_ok=True)
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        content = source.read_text(encoding="utf-8")
        replacements = {
            "ExampleApp": str(manifest["product_name"]),
            "Example App": str(manifest["name"]),
            "br.com.example.app": str(manifest["bundle_id"]),
        }
        for old, new in replacements.items():
            content = content.replace(old, new)
        target.write_text(content, encoding="utf-8")
    (destination / "app.yml").write_text(manifest_path.read_text(encoding="utf-8"), encoding="utf-8")
    tools = destination / "tools"
    tools.mkdir(exist_ok=True)
    (tools / "jerv_cli.py").write_text(Path(__file__).read_text(encoding="utf-8"), encoding="utf-8")
    print(f"initialized {destination}")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="jerv")
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("validate", "release-check", "audit"):
        command = sub.add_parser(name)
        command.add_argument("manifest", type=Path)
    init = sub.add_parser("init")
    init.add_argument("destination", type=Path)
    init.add_argument("--manifest", required=True, type=Path)
    args = parser.parse_args(argv)
    if args.command == "validate":
        return run_validation(args.manifest)
    if args.command == "release-check":
        return run_validation(args.manifest, release=True)
    if args.command == "audit":
        return audit(args.manifest)
    return init_project(args.destination, args.manifest)


if __name__ == "__main__":
    sys.exit(main())
