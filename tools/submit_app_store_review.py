#!/usr/bin/env python3
"""Attach the processed production build and submit App Store version 1.0."""

from __future__ import annotations

import json
import os
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

import jwt


API_ROOT = "https://api.appstoreconnect.apple.com/v1"
BUNDLE_ID = "br.com.restaurantes.bsb"
APP_STORE_ID = "6813989690"
MARKETING_VERSION = "1.0"
BUILD_NUMBER = "3"
ACTIVE_REVIEW_STATES = {"READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES"}


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
            payload = response.read()
            return json.loads(payload) if payload else {}
    except HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        try:
            errors = json.loads(detail).get("errors", [])
            messages = []
            for item in errors:
                parts = [item.get("code"), item.get("title"), item.get("detail")]
                message = ": ".join(str(part) for part in parts if part)
                if item.get("meta"):
                    message += f" (meta: {json.dumps(item['meta'], sort_keys=True)})"
                messages.append(message)
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


def app_record() -> dict:
    query = urlencode({"filter[bundleId]": BUNDLE_ID, "limit": "200"})
    matches = [item for item in list_pages(f"/apps?{query}") if item.get("id") == APP_STORE_ID]
    if len(matches) != 1:
        raise RuntimeError(f"Expected App Store Connect app {APP_STORE_ID} with bundle ID {BUNDLE_ID}; found {len(matches)}")
    return matches[0]


def app_store_version(app_id: str) -> dict:
    query = urlencode({"filter[platform]": "IOS", "filter[versionString]": MARKETING_VERSION, "limit": "200"})
    versions = list_pages(f"/apps/{app_id}/appStoreVersions?{query}")
    if len(versions) != 1:
        raise RuntimeError(f"Expected one iOS App Store version {MARKETING_VERSION}; found {len(versions)}")
    return versions[0]


def prerelease_version_for(build: dict, included: list[dict]) -> str | None:
    relationship = build.get("relationships", {}).get("preReleaseVersion", {}).get("data") or {}
    version_id = relationship.get("id")
    if not version_id:
        return None
    for item in included:
        if item.get("type") == "preReleaseVersions" and item.get("id") == version_id:
            return item.get("attributes", {}).get("version")
    details = api_request(f"/preReleaseVersions/{version_id}").get("data", {})
    return details.get("attributes", {}).get("version")


def find_valid_build(app_id: str) -> dict:
    query = urlencode(
        {
            "filter[app]": app_id,
            "filter[version]": BUILD_NUMBER,
            "filter[preReleaseVersion.version]": MARKETING_VERSION,
            "filter[preReleaseVersion.platform]": "IOS",
            "include": "preReleaseVersion",
            "limit": "200",
        }
    )
    timeout_minutes = int(os.environ.get("APP_STORE_PROCESSING_TIMEOUT_MINUTES", "60"))
    deadline = time.monotonic() + timeout_minutes * 60
    while time.monotonic() < deadline:
        response = api_request(f"/builds?{query}")
        builds = response.get("data", [])
        included = response.get("included", [])
        for build in builds:
            attributes = build.get("attributes", {})
            if str(attributes.get("version", "")) != BUILD_NUMBER:
                continue
            if prerelease_version_for(build, included) != MARKETING_VERSION:
                continue
            state = attributes.get("processingState", "UNKNOWN")
            print(f"Found App Store Connect build {MARKETING_VERSION} ({BUILD_NUMBER}): {state}")
            if state == "VALID":
                return build
            if state == "INVALID":
                raise RuntimeError(f"Apple marked build {MARKETING_VERSION} ({BUILD_NUMBER}) invalid")
        time.sleep(30)
    raise RuntimeError(
        f"App Store Connect did not report a VALID build {MARKETING_VERSION} ({BUILD_NUMBER}) "
        f"within {timeout_minutes} minutes"
    )


def active_submission(app_id: str, version_id: str) -> dict | None:
    submissions = list_pages(f"/apps/{app_id}/reviewSubmissions?limit=200")
    for submission in submissions:
        attributes = submission.get("attributes", {})
        relationships = submission.get("relationships", {})
        version_relationship = relationships.get("appStoreVersionForReview", {}).get("data") or {}
        if attributes.get("state") in ACTIVE_REVIEW_STATES and version_relationship.get("id") == version_id:
            return submission
    return None


def review_submission_summary(app_id: str) -> list[str]:
    response = api_request(f"/apps/{app_id}/reviewSubmissions?limit=200&include=items,appStoreVersionForReview")
    included_items = {
        item.get("id"): item
        for item in response.get("included", [])
        if item.get("type") == "reviewSubmissionItems"
    }
    summary = []
    for item in response.get("data", []):
        attributes = item.get("attributes", {})
        relationships = item.get("relationships", {})
        version_id = (relationships.get("appStoreVersionForReview", {}).get("data") or {}).get("id", "")
        item_ids = (relationships.get("items", {}).get("data") or [])
        version_ids = []
        for review_item_id in item_ids:
            review_item = included_items.get(review_item_id.get("id"), {})
            related_version = (review_item.get("relationships", {}).get("appStoreVersion", {}).get("data") or {}).get("id")
            if related_version:
                version_ids.append(related_version)
        summary.append(
            f"{item.get('id')} state={attributes.get('state', 'UNKNOWN')} "
            f"appStoreVersionForReview={version_id or 'none'} items={','.join(version_ids) or 'none'}"
        )
    return summary


def submit_for_review(app_id: str, version_id: str) -> dict:
    existing = active_submission(app_id, version_id)
    if existing:
        state = existing.get("attributes", {}).get("state")
        if state in {"READY_FOR_REVIEW", "UNRESOLVED_ISSUES"}:
            return api_request(
                f"/reviewSubmissions/{existing['id']}",
                method="PATCH",
                body={
                    "data": {
                        "type": "reviewSubmissions",
                        "id": existing["id"],
                        "attributes": {"submitted": True},
                    }
                },
            )["data"]
        raise RuntimeError(
            f"Version {MARKETING_VERSION} already has an App Review submission in state {state}; "
            "refusing to create a duplicate"
        )

    submission = api_request(
        "/reviewSubmissions",
        method="POST",
        body={
            "data": {
                "type": "reviewSubmissions",
                "attributes": {"platform": "IOS"},
                "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
            }
        },
    )["data"]
    submission_id = submission["id"]

    api_request(
        "/reviewSubmissionItems",
        method="POST",
        body={
            "data": {
                "type": "reviewSubmissionItems",
                "relationships": {
                    "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission_id}},
                    "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}},
                },
            }
        },
    )
    return api_request(
        f"/reviewSubmissions/{submission_id}",
        method="PATCH",
        body={
            "data": {
                "type": "reviewSubmissions",
                "id": submission_id,
                "attributes": {"submitted": True},
            }
        },
    )["data"]


def main() -> None:
    app = app_record()
    version = app_store_version(app["id"])
    version_state = version.get("attributes", {}).get("appStoreState", "UNKNOWN")
    if version_state not in {"REJECTED", "PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED"}:
        raise RuntimeError(
            f"App Store version {MARKETING_VERSION} is in state {version_state}; "
            "refusing to modify or create another review submission"
        )

    build = find_valid_build(app["id"])
    current_build = api_request(f"/appStoreVersions/{version['id']}/build").get("data")
    print(f"App Store version {MARKETING_VERSION}: state={version_state}, id={version['id']}")
    print(f"Current attached build: {current_build.get('id', 'none') if current_build else 'none'}")
    print(f"Target build: {build['id']} (build {BUILD_NUMBER}, processing={build.get('attributes', {}).get('processingState')})")
    submissions = review_submission_summary(app["id"])
    if submissions:
        print("Existing App Review submissions:")
        for submission in submissions:
            print(f"- {submission}")
    else:
        print("No existing App Review submissions found.")

    operation = os.environ.get("ASC_ACTION", "submit").strip().lower()
    if operation == "inspect":
        summary = (
            f"### App Store Connect release state inspected\n"
            f"- App: `{BUNDLE_ID}`\n"
            f"- Version: `{MARKETING_VERSION}` (`{version_state}`)\n"
            f"- Target build: `{MARKETING_VERSION} ({BUILD_NUMBER})` (`{build.get('attributes', {}).get('processingState')}`)\n"
            f"- Current attached build: `{current_build.get('id', 'none') if current_build else 'none'}`\n"
        )
        write_summary(summary)
        return
    if operation != "submit":
        raise RuntimeError(f"Unknown operation {operation!r}; use inspect or submit")

    if not current_build or current_build.get("id") != build["id"]:
        api_request(
            f"/appStoreVersions/{version['id']}/relationships/build",
            method="PATCH",
            body={"data": {"type": "builds", "id": build["id"]}},
        )

    submission = submit_for_review(app["id"], version["id"])
    summary = (
        "### App Store version submitted for review\n"
        f"- App: `{BUNDLE_ID}`\n"
        f"- Version/build: `{MARKETING_VERSION} ({BUILD_NUMBER})`\n"
        f"- Build ID: `{build['id']}`\n"
        f"- Review submission ID: `{submission['id']}`\n"
        f"- Review state: `{submission.get('attributes', {}).get('state', 'submitted')}`\n"
    )
    print(summary)
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as summary_file:
            summary_file.write(summary + "\n")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"::error::{error}")
        sys.exit(1)
