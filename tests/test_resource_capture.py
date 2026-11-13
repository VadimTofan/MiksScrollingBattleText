import unittest
from pathlib import Path

from tests.lua_test_runner import run_lua_test


ROOT = Path(__file__).resolve().parents[1]


# Describe: resource-source capture is an optional development diagnostic.
class ResourceCaptureTests(unittest.TestCase):
    def test_capture_records_payload_shape_without_inspecting_secrets(self):
        # Given
        script = "resource_capture.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_capture_stays_out_of_release_manifests_and_packages(self):
        # Given
        for manifest in ROOT.glob("MikScrollingBattleText*.toc"):
            # When
            files = manifest.read_text(encoding="utf-8-sig").replace("\\", "/")

            # Then
            self.assertNotIn("Diagnostics/ResourceCapture.lua", files)

        # Given / When
        exclusions = (ROOT / ".pkgmeta").read_text(encoding="utf-8")

        # Then
        self.assertIn("  - Diagnostics\n", exclusions)
