#!/usr/bin/env python3
"""Trigger and verify the App Store Xcode Cloud build for this repository."""

from __future__ import annotations

import json
import os
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

import jwt


API_ROOT = "https://api.appstoreconnect.apple.com/v1"
BUNDLE_ID = "br.com.restaurantes.bsb"
REPOSITORY_OWNER = "socialbot114-cell"
REPOSITORY_NAME = "restaurantes-brasilia-ios"
MARKETING_VERSION = "1.0"
BUILD_NUMBER = "3"


def make_token() -> str:
    now = int(time.time())
    return jwt.encode(
        {
            "iss": os.environ["APPLE_API_ISSUER_ID"],
            "iat": now,
            "exp": now + 15 * 60,
            "aud": "appstoreconnect-v1",
        },
        os.environ["APPLE_API_KEY_P8"],
        algorithm="ES256",
        headers={"kid": os.environ["APPLE_API_KEY_ID"], "typ": "JWT"},
    )


TOKEN = make_token()


def api_request(path: str, method: str = "GET", body: dict | None = None) -> dict:
    data = json.dumps(body).encode() if body is not None else None
    url = path if path.startswith("https://") else f"{API_ROOT}{path}"
    request = Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {TOKEN}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        },
    )
    try:
        with urlopen(request, timeout=30) as response:
            return json.load(response)
    except HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        try:
            messages = [item.get("detail", "") for item in json.loads(detail).get("errors", [])]
        except (json.JSONDecodeError, AttributeError):
            messages = []
        reason = "; ".join(message for message in messages if message) or "Apple returned an API error"
        raise RuntimeError(f"App Store Connect API returned HTTP {error.code}: {reason}") from None
    except URLError as error:
        raise RuntimeError(f"Could not reach App Store Connect: {error.reason}") from None


def list_pages(path: str) -> list[dict]:
    items: list[dict] = []
    next_url: str | None = path
    while next_url:
        response = api_request(next_url)
        items.extend(response.get("data", []))
        next_url = response.get("links", {}).get("next")
    return items


def related_app_id(product_id: str) -> str | None:
    app = api_request(f"/ciProducts/{product_id}/app").get("data")
    return app.get("id") if app else None


def select_workflow(product_id: str) -> dict:
    workflows = list_pages(f"/ciProducts/{product_id}/workflows?limit=200")
    enabled = [workflow for workflow in workflows if workflow.get("attributes", {}).get("isEnabled", True)]
    requested_name = os.environ.get("XCODE_CLOUD_WORKFLOW_NAME", "").strip()

    if requested_name:
        matches = [workflow for workflow in enabled if workflow.get("attributes", {}).get("name") == requested_name]
        if len(matches) != 1:
            choices = ", ".join(workflow.get("attributes", {}).get("name", "(unnamed)") for workflow in enabled)
            raise RuntimeError(f"No unique enabled workflow named {requested_name!r}. Available: {choices or '(none)'}")
        return matches[0]

    if len(enabled) != 1:
        choices = ", ".join(workflow.get("attributes", {}).get("name", "(unnamed)") for workflow in enabled)
        raise RuntimeError(
            f"Expected one enabled Xcode Cloud workflow; found {len(enabled)}: {choices or '(none)'}. "
            "Dispatch again with the exact workflow name after confirming it archives and distributes to App Store Connect."
        )
    return enabled[0]


def select_repository() -> dict:
    repositories = list_pages("/scmRepositories?limit=200")
    matches = []
    for repository in repositories:
        values = " ".join(str(value) for value in repository.get("attributes", {}).values()).lower()
        if REPOSITORY_NAME.lower() in values and REPOSITORY_OWNER.lower() in values:
            matches.append(repository)
    if len(matches) != 1:
        raise RuntimeError(
            f"Expected one Xcode Cloud repository for {REPOSITORY_OWNER}/{REPOSITORY_NAME}; found {len(matches)}"
        )
    return matches[0]


def select_branch(repository_id: str, branch_name: str) -> dict:
    references = list_pages(f"/scmRepositories/{repository_id}/gitReferences?limit=200")
    matches = []
    for reference in references:
        attributes = reference.get("attributes", {})
        names = {str(attributes.get(key, "")) for key in ("name", "canonicalName")}
        if (branch_name in names or f"refs/heads/{branch_name}" in names) and not attributes.get("isDeleted", False):
            matches.append(reference)
    if len(matches) != 1:
        raise RuntimeError(
            f"Xcode Cloud has no unique Git reference for branch {branch_name!r}; found {len(matches)}"
        )
    return matches[0]


def write_summary(text: str) -> None:
    print(text)
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as summary:
            summary.write(text + "\n")


def find_distribution_build(run_id: str, timeout_minutes: int) -> dict:
    deadline = time.monotonic() + timeout_minutes * 60
    while time.monotonic() < deadline:
        response = api_request(f"/ciBuildRuns/{run_id}/builds?limit=200&include=preReleaseVersion")
        included_versions = {
            item["id"]: item.get("attributes", {}).get("version")
            for item in response.get("included", [])
            if item.get("type") == "preReleaseVersions"
        }
        for build in response.get("data", []):
            attributes = build.get("attributes", {})
            build_number = str(attributes.get("version", ""))
            relationship = build.get("relationships", {}).get("preReleaseVersion", {}).get("data") or {}
            marketing_version = included_versions.get(relationship.get("id"))
            if marketing_version is None and relationship.get("id"):
                pre_release = api_request(f"/preReleaseVersions/{relationship['id']}").get("data", {})
                marketing_version = pre_release.get("attributes", {}).get("version")
            if build_number == BUILD_NUMBER and marketing_version == MARKETING_VERSION:
                state = attributes.get("processingState", "UNKNOWN")
                if state == "VALID":
                    return build
                if state == "INVALID":
                    raise RuntimeError(f"App Store Connect rejected build {MARKETING_VERSION} ({BUILD_NUMBER}) during processing")
                print(f"App Store Connect is processing build {MARKETING_VERSION} ({BUILD_NUMBER}): {state}")
        time.sleep(30)
    raise RuntimeError(
        f"Xcode Cloud completed, but App Store Connect did not report a VALID build {MARKETING_VERSION} ({BUILD_NUMBER}) "
        f"within {timeout_minutes} minutes. Confirm the selected Xcode Cloud workflow distributes to App Store Connect."
    )


def main() -> None:
    bundle_query = "filter[bundleId]=" + BUNDLE_ID + "&limit=200"
    apps = list_pages(f"/apps?{bundle_query}")
    if len(apps) != 1:
        raise RuntimeError(f"Expected one App Store Connect app with bundle ID {BUNDLE_ID}; found {len(apps)}")
    app = apps[0]

    products = list_pages("/ciProducts?limit=200")
    products_for_app = [product for product in products if related_app_id(product["id"]) == app["id"]]
    if len(products_for_app) != 1:
        raise RuntimeError(
            f"Expected one Xcode Cloud product for {BUNDLE_ID}; found {len(products_for_app)}. "
            "Connect the app and repository to Xcode Cloud in App Store Connect first."
        )
    product = products_for_app[0]
    workflow = select_workflow(product["id"])
    repository = select_repository()
    branch_name = os.environ["GITHUB_REF_NAME"]
    branch = select_branch(repository["id"], branch_name)

    body = {
        "data": {
            "type": "ciBuildRuns",
            "attributes": {},
            "relationships": {
                "workflow": {"data": {"type": "ciWorkflows", "id": workflow["id"]}},
                "sourceBranchOrTag": {"data": {"type": "scmGitReferences", "id": branch["id"]}},
            },
        }
    }
    build_run = api_request("/ciBuildRuns", method="POST", body=body)["data"]
    run_id = build_run["id"]
    expected_sha = os.environ.get("GITHUB_SHA", "")
    run_timeout = int(os.environ.get("XCODE_CLOUD_RUN_TIMEOUT_MINUTES", "90"))
    deadline = time.monotonic() + run_timeout * 60
    last_progress = None

    while time.monotonic() < deadline:
        current = api_request(f"/ciBuildRuns/{run_id}")["data"]
        attributes = current.get("attributes", {})
        progress = attributes.get("executionProgress", "PENDING")
        completion = attributes.get("completionStatus")
        source_sha = attributes.get("sourceCommit", {}).get("commitSha")
        if progress != last_progress:
            print(f"Xcode Cloud build {run_id}: {progress} ({completion or 'in progress'})")
            last_progress = progress
        if source_sha and expected_sha and source_sha.lower() != expected_sha.lower():
            raise RuntimeError(f"Xcode Cloud built commit {source_sha}, expected {expected_sha}")
        if progress == "COMPLETE":
            if completion != "SUCCEEDED":
                raise RuntimeError(f"Xcode Cloud build {run_id} finished with status {completion or 'unknown'}")
            break
        time.sleep(30)
    else:
        raise RuntimeError(f"Xcode Cloud build {run_id} did not finish within {run_timeout} minutes")

    build = find_distribution_build(run_id, int(os.environ.get("APP_STORE_PROCESSING_TIMEOUT_MINUTES", "45")))
    build_attributes = build.get("attributes", {})
    summary = (
        "### Xcode Cloud production build succeeded\n"
        f"- App: `{BUNDLE_ID}`\n"
        f"- Version/build: `{MARKETING_VERSION} ({BUILD_NUMBER})`\n"
        f"- Workflow: `{workflow.get('attributes', {}).get('name', workflow['id'])}`\n"
        f"- Branch: `{branch_name}`\n"
        f"- Commit: `{expected_sha}`\n"
        f"- Xcode Cloud run: `{run_id}`\n"
        f"- App Store Connect build ID: `{build['id']}`\n"
        f"- Processing state: `{build_attributes.get('processingState', 'VALID')}`\n"
    )
    write_summary(summary)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"::error::{error}")
        sys.exit(1)
