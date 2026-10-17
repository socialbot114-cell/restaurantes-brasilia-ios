import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from jerv_cli import validate_catalog


class PhotoRightsReleaseGateTests(unittest.TestCase):
    def validate(self, records, release=True):
        with tempfile.TemporaryDirectory() as temporary_directory:
            base = Path(temporary_directory)
            (base / "catalog.json").write_text(json.dumps(records), encoding="utf-8")
            manifest = {
                "catalog": {
                    "path": "catalog.json",
                    "required_fields": ["id", "name"],
                    "authorized_photo_rights_statuses": ["user-confirmed-authorized"],
                }
            }
            return validate_catalog(manifest, base, release=release)

    def test_release_rejects_attributed_photo_without_redistribution_permission(self):
        errors = self.validate(
            [{"id": "one", "name": "Lugar", "photo_asset": "Photo", "photo_rights_status": "source-attributed"}]
        )

        self.assertTrue(any("1 photo assets" in error for error in errors))

    def test_release_accepts_explicitly_authorized_photo(self):
        errors = self.validate(
            [
                {
                    "id": "one",
                    "name": "Lugar",
                    "photo_asset": "Photo",
                    "photo_rights_status": "user-confirmed-authorized",
                }
            ]
        )

        self.assertEqual(errors, [])

    def test_release_does_not_require_photo_permission_for_records_without_photos(self):
        errors = self.validate([{"id": "one", "name": "Lugar"}])

        self.assertEqual(errors, [])


if __name__ == "__main__":
    unittest.main()
