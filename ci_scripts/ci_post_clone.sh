#!/bin/sh
set -eu
cd "$CI_PRIMARY_REPOSITORY_PATH"
if command -v brew >/dev/null 2>&1; then brew install xcodegen || true; fi
xcodegen generate --spec project.yml
python3 -m venv .venv
.venv/bin/pip install --disable-pip-version-check PyYAML
.venv/bin/python tools/jerv_cli.py validate app.yml
