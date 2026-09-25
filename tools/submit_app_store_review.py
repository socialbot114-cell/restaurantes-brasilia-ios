#!/usr/bin/env python3
"""Attach the processed production build and submit App Store version 1.0."""

from __future__ import annotations

import json
import hashlib
import os
import sys
import time
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

import jwt
from PIL import Image, ImageOps


API_ROOT = "https://api.appstoreconnect.apple.com/v1"
BUNDLE_ID = "br.com.restaurantes.bsb"
APP_STORE_ID = "6813989690"
MARKETING_VERSION = "1.0"
BUILD_NUMBER = "3"
RELEASE_NOTES_PT_BR = (
    "Crie e organize roteiros de restaurantes, registre visitas com avaliações e anotações pessoais "
    "e consulte locais no mapa integrado. Seus roteiros e seu diário ficam salvos no aparelho."
)
IPHONE_SCREENSHOT_SIZE = (1290, 2796)
IPAD_SCREENSHOT_SIZE = (1668, 2388)
APP_STORE_SCREENSHOTS = (
    "restaurantes-home",
    "restaurantes-verona-busca",
    "restaurantes-detalhe",
    "restaurantes-explore",
    "restaurantes-diario",
    "restaurantes-roteiro-planejado",
)
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


def write_summary(text: str) -> None:
    print(text)
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as summary_file:
            summary_file.write(text + "\n")


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


def prepare_screenshots(artifact_dir: Path, output_name: str, size: tuple[int, int]) -> list[Path]:
    manifest = json.loads((artifact_dir / "manifest.json").read_text(encoding="utf-8"))
    attachments = [attachment for test in manifest for attachment in test.get("attachments", [])]
    by_name = {
        attachment.get("suggestedHumanReadableName", "").split("_0_")[0]: artifact_dir / attachment["exportedFileName"]
        for attachment in attachments
        if attachment.get("exportedFileName", "").lower().endswith(".png")
    }
    missing = [name for name in APP_STORE_SCREENSHOTS if name not in by_name]
    if missing:
        raise RuntimeError(f"Screenshot artifact is missing required captures: {', '.join(missing)}")

    output_dir = artifact_dir / output_name
    output_dir.mkdir(parents=True, exist_ok=True)
    prepared = []
    for index, name in enumerate(APP_STORE_SCREENSHOTS, start=1):
        output_file = output_dir / f"{index:02d}-{name}.png"
        with Image.open(by_name[name]) as source:
            image = ImageOps.fit(source.convert("RGB"), size, method=Image.Resampling.LANCZOS)
            image.save(output_file, format="PNG", optimize=True)
        prepared.append(output_file)
    return prepared


def screenshot_set_for(localization_id: str, display_type: str) -> tuple[str, bool]:
    sets = list_pages(f"/appStoreVersionLocalizations/{localization_id}/appScreenshotSets?limit=200")
    existing = [
        screenshot_set
        for screenshot_set in sets
        if screenshot_set.get("attributes", {}).get("screenshotDisplayType") == display_type
    ]
    for screenshot_set in existing:
        screenshots = list_pages(f"/appScreenshotSets/{screenshot_set['id']}/appScreenshots?limit=200")
        if len(screenshots) >= len(APP_STORE_SCREENSHOTS) and all(
            item.get("attributes", {}).get("assetDeliveryState", {}).get("state") == "COMPLETE"
            for item in screenshots[: len(APP_STORE_SCREENSHOTS)]
        ):
            print(f"Reusing complete App Store screenshot set {display_type}.")
            return screenshot_set["id"], True
        api_request(f"/appScreenshotSets/{screenshot_set['id']}", method="DELETE")

    response = api_request(
        "/appScreenshotSets",
        method="POST",
        body={
            "data": {
                "type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": display_type},
                "relationships": {
                    "appStoreVersionLocalization": {
                        "data": {"type": "appStoreVersionLocalizations", "id": localization_id}
                    }
                },
            }
        },
    )
    return response["data"]["id"], False


def upload_screenshot(screenshot_set_id: str, path: Path) -> str:
    content = path.read_bytes()
    reservation = api_request(
        "/appScreenshots",
        method="POST",
        body={
            "data": {
                "type": "appScreenshots",
                "attributes": {"fileName": path.name, "fileSize": len(content)},
                "relationships": {
                    "appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": screenshot_set_id}}
                },
            }
        },
    )["data"]
    screenshot_id = reservation["id"]
    operations = reservation.get("attributes", {}).get("uploadOperations", [])
    if not operations:
        raise RuntimeError(f"Apple did not return upload instructions for screenshot {path.name}")

    for operation in operations:
        offset = operation["offset"]
        length = operation["length"]
        chunk = content[offset : offset + length]
        headers = {item["name"]: item["value"] for item in operation.get("requestHeaders", [])}
        request = Request(operation["url"], data=chunk, method=operation["method"], headers=headers)
        try:
            with urlopen(request, timeout=120) as response:
                response.read()
        except (HTTPError, URLError) as error:
            raise RuntimeError(f"Could not upload App Store screenshot {path.name}: {error}") from None

    api_request(
        f"/appScreenshots/{screenshot_id}",
        method="PATCH",
        body={
            "data": {
                "type": "appScreenshots",
                "id": screenshot_id,
                "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(content).hexdigest()},
            }
        },
    )
    deadline = time.monotonic() + 5 * 60
    while time.monotonic() < deadline:
        screenshot = api_request(f"/appScreenshots/{screenshot_id}").get("data", {})
        delivery = screenshot.get("attributes", {}).get("assetDeliveryState", {})
        state = delivery.get("state")
        if state == "COMPLETE":
            return screenshot_id
        if state == "FAILED":
            errors = delivery.get("errors", [])
            detail = json.dumps(errors, sort_keys=True) if errors else "processing failed without details"
            raise RuntimeError(f"App Store Connect rejected screenshot {path.name} (id {screenshot_id}): {detail}")
        time.sleep(10)
    raise RuntimeError(f"App Store Connect did not finish processing screenshot {path.name}")


def upload_screenshot_set(
    localization_id: str,
    artifact_dir: Path,
    output_name: str,
    display_type: str,
    size: tuple[int, int],
) -> int:
    screenshots = prepare_screenshots(artifact_dir, output_name, size)
    set_id, already_complete = screenshot_set_for(localization_id, display_type)
    if already_complete:
        return len(APP_STORE_SCREENSHOTS)
    uploaded = 0
    for screenshot in screenshots:
        upload_screenshot(set_id, screenshot)
        uploaded += 1
        print(f"Uploaded App Store screenshot ({display_type}): {screenshot.name}")
    return uploaded


def upload_store_screenshots(app_store_version_id: str) -> int:
    localizations = list_pages(f"/appStoreVersions/{app_store_version_id}/appStoreVersionLocalizations?limit=200")
    locale = next((item for item in localizations if item.get("attributes", {}).get("locale") == "pt-BR"), None)
    if not locale:
        available = ", ".join(item.get("attributes", {}).get("locale", "?") for item in localizations)
        raise RuntimeError(f"No pt-BR App Store localization exists for version {MARKETING_VERSION}; found: {available or '(none)'}")

    iphone_dir = Path(os.environ["ASC_SCREENSHOT_IPHONE_DIR"])
    ipad_dir = Path(os.environ["ASC_SCREENSHOT_IPAD_DIR"])
    iphone_count = upload_screenshot_set(
        locale["id"], iphone_dir, "app-store-iphone-67", "APP_IPHONE_67", IPHONE_SCREENSHOT_SIZE
    )
    ipad_count = upload_screenshot_set(
        locale["id"], ipad_dir, "app-store-ipad-11", "APP_IPAD_PRO_3GEN_11", IPAD_SCREENSHOT_SIZE
    )
    return iphone_count + ipad_count


def ensure_release_notes(app_store_version_id: str) -> None:
    localizations = list_pages(f"/appStoreVersions/{app_store_version_id}/appStoreVersionLocalizations?limit=200")
    locale = next((item for item in localizations if item.get("attributes", {}).get("locale") == "pt-BR"), None)
    if not locale:
        raise RuntimeError(f"No pt-BR App Store localization exists for version {MARKETING_VERSION}")
    if locale.get("attributes", {}).get("whatsNew"):
        print("App Store release notes are already present for pt-BR.")
        return
    api_request(
        f"/appStoreVersionLocalizations/{locale['id']}",
        method="PATCH",
        body={
            "data": {
                "type": "appStoreVersionLocalizations",
                "id": locale["id"],
                "attributes": {"whatsNew": RELEASE_NOTES_PT_BR},
            }
        },
    )
    print("Added Portuguese release notes describing the new native routes and visit diary.")


def inspect_screenshot_sets(app_store_version_id: str) -> None:
    localizations = list_pages(f"/appStoreVersions/{app_store_version_id}/appStoreVersionLocalizations?limit=200")
    locale = next((item for item in localizations if item.get("attributes", {}).get("locale") == "pt-BR"), None)
    if not locale:
        print("No pt-BR App Store localization is present yet.")
        return
    sets = list_pages(f"/appStoreVersionLocalizations/{locale['id']}/appScreenshotSets?limit=200")
    for screenshot_set in sets:
        attributes = screenshot_set.get("attributes", {})
        display_type = attributes.get("screenshotDisplayType")
        if display_type not in {"APP_IPHONE_67", "APP_IPAD_PRO_3GEN_11"}:
            continue
        print(f"Screenshot set {display_type}: {screenshot_set['id']}")
        screenshots = list_pages(f"/appScreenshotSets/{screenshot_set['id']}/appScreenshots?limit=200")
        for screenshot in screenshots:
            screenshot_attributes = screenshot.get("attributes", {})
            delivery_state = screenshot_attributes.get("assetDeliveryState", {})
            print(
                f"- {screenshot_attributes.get('fileName', '(unnamed)')}: "
                f"{delivery_state.get('state', 'UNKNOWN')} "
                f"{json.dumps(delivery_state.get('errors', []), sort_keys=True)}"
            )


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
    submissions = list_pages(f"/apps/{app_id}/reviewSubmissions?limit=200&include=appStoreVersionForReview,items")
    for submission in submissions:
        attributes = submission.get("attributes", {})
        relationships = submission.get("relationships", {})
        version_relationship = relationships.get("appStoreVersionForReview", {}).get("data") or {}
        if attributes.get("state") in ACTIVE_REVIEW_STATES and version_relationship.get("id") == version_id:
            return submission
    return None


def resolve_previous_review_issues(app_id: str, version_id: str) -> None:
    submissions = list_pages(f"/apps/{app_id}/reviewSubmissions?limit=200&include=appStoreVersionForReview,items")
    matching = [
        submission
        for submission in submissions
        if (submission.get("relationships", {}).get("appStoreVersionForReview", {}).get("data") or {}).get("id") == version_id
        and submission.get("attributes", {}).get("state") == "UNRESOLVED_ISSUES"
    ]
    for submission in matching:
        items = list_pages(f"/reviewSubmissions/{submission['id']}/items?limit=200&include=appStoreVersion")
        rejected_items = [item for item in items if item.get("attributes", {}).get("state") == "REJECTED"]
        if not rejected_items:
            continue
        for item in rejected_items:
            item_version_id = (item.get("relationships", {}).get("appStoreVersion", {}).get("data") or {}).get("id")
            if item_version_id and item_version_id != version_id:
                continue
            if not item_version_id and len(items) != 1:
                raise RuntimeError(
                    f"Review submission {submission['id']} has multiple rejected items without version links; "
                    "refusing to resolve an ambiguous item"
                )
            api_request(
                f"/reviewSubmissionItems/{item['id']}",
                method="PATCH",
                body={
                    "data": {
                        "type": "reviewSubmissionItems",
                        "id": item["id"],
                        "attributes": {"resolved": True},
                    }
                },
            )
            print(f"Marked the prior rejected App Review item {item['id']} as resolved.")


def cancel_stale_review_submissions(app_id: str, version_id: str) -> None:
    submissions = list_pages(f"/apps/{app_id}/reviewSubmissions?limit=200&include=appStoreVersionForReview,items")
    for submission in submissions:
        attributes = submission.get("attributes", {})
        state = attributes.get("state")
        relationships = submission.get("relationships", {})
        related_version = (relationships.get("appStoreVersionForReview", {}).get("data") or {}).get("id")
        linked_items = relationships.get("items", {}).get("data") or []
        has_items = bool(linked_items)
        if state == "READY_FOR_REVIEW" and not related_version and not has_items:
            has_items = bool(list_pages(f"/reviewSubmissions/{submission['id']}/items?limit=200"))
        is_target_submission = related_version == version_id
        is_empty_draft = state == "READY_FOR_REVIEW" and not related_version and not has_items
        if is_target_submission or not is_empty_draft:
            continue
        result = api_request(
            f"/reviewSubmissions/{submission['id']}",
            method="PATCH",
            body={
                "data": {
                    "type": "reviewSubmissions",
                    "id": submission["id"],
                    "attributes": {"canceled": True},
                }
            },
        )["data"]
        deadline = time.monotonic() + 180
        while result.get("attributes", {}).get("state") == "CANCELING" and time.monotonic() < deadline:
            time.sleep(5)
            result = api_request(f"/reviewSubmissions/{submission['id']}").get("data", {})
        state_after_cancel = result.get("attributes", {}).get("state")
        if state_after_cancel not in {"COMPLETE"} and not result.get("attributes", {}).get("canceled", False):
            raise RuntimeError(
                f"Could not clear stale App Review submission {submission['id']} (state={state_after_cancel})"
            )
        print(f"Canceled stale App Review submission {submission['id']} ({state}).")


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
        review_items = [included_items.get(review_item_id.get("id"), {}) for review_item_id in item_ids]
        if not review_items:
            item_response = api_request(f"/reviewSubmissions/{item['id']}/items?limit=200&include=appStoreVersion")
            review_items = item_response.get("data", [])
        item_details = []
        for review_item_id in item_ids:
            review_item = included_items.get(review_item_id.get("id"), {})
            item_details.append(review_item)
        if not item_details:
            item_details = review_items
        item_summary = []
        for review_item in item_details:
            related_version = (review_item.get("relationships", {}).get("appStoreVersion", {}).get("data") or {}).get("id")
            item_summary.append(
                f"{review_item.get('id', '?')} state={review_item.get('attributes', {}).get('state', 'UNKNOWN')} "
                f"version={related_version or 'none'}"
            )
        summary.append(
            f"{item.get('id')} state={attributes.get('state', 'UNKNOWN')} "
            f"appStoreVersionForReview={version_id or 'none'} items={';'.join(item_summary) or 'none'}"
        )
    return summary


def review_readiness_summary(version_id: str) -> list[str]:
    summary = []
    try:
        detail = api_request(f"/appStoreVersions/{version_id}/appStoreReviewDetail").get("data", {}).get("attributes", {})
        required_fields = ("contactFirstName", "contactLastName", "contactEmail", "contactPhone", "notes")
        missing = [field for field in required_fields if not detail.get(field)]
        summary.append(f"App Review contact/notes missing fields: {','.join(missing) or 'none'}")
    except RuntimeError as error:
        summary.append(f"App Review detail lookup: {error}")

    localizations = list_pages(f"/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=200")
    pt_br = next((item for item in localizations if item.get("attributes", {}).get("locale") == "pt-BR"), None)
    if not pt_br:
        summary.append("pt-BR App Store version localization is missing")
    else:
        attributes = pt_br.get("attributes", {})
        required_fields = ("description", "keywords", "supportUrl", "whatsNew")
        missing = [field for field in required_fields if not attributes.get(field)]
        summary.append(f"pt-BR App Store localization missing fields: {','.join(missing) or 'none'}")
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
    if version_state not in {"REJECTED", "PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW", "DEVELOPER_REJECTED"}:
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
    for readiness in review_readiness_summary(version["id"]):
        print(readiness)

    operation = os.environ.get("ASC_ACTION", "submit").strip().lower()
    if operation == "inspect":
        inspect_screenshot_sets(version["id"])
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

    resolve_previous_review_issues(app["id"], version["id"])
    cancel_stale_review_submissions(app["id"], version["id"])
    ensure_release_notes(version["id"])
    uploaded_count = upload_store_screenshots(version["id"])
    print(f"Uploaded {uploaded_count} App Store screenshots for pt-BR.")

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
        f"- App Store screenshots uploaded: `{uploaded_count}`\n"
        f"- Build ID: `{build['id']}`\n"
        f"- Review submission ID: `{submission['id']}`\n"
        f"- Review state: `{submission.get('attributes', {}).get('state', 'submitted')}`\n"
    )
    write_summary(summary)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"::error::{error}")
        sys.exit(1)
