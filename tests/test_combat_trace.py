import unittest
from pathlib import Path

from tests.lua_test_runner import run_lua_test


ROOT = Path(__file__).resolve().parents[1]


# Describe: optional damage tracing preserves combat behavior and opaque values.
class CombatTraceTests(unittest.TestCase):
    def test_trace_is_opt_in_bounded_and_preserves_damage_arguments(self):
        # Given
        script = "combat_trace.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_temporary_trace_stays_out_of_both_release_manifests(self):
        # Given
        for manifest in ROOT.glob("MikScrollingBattleText*.toc"):
            files = manifest.read_text(encoding="utf-8-sig").replace("\\", "/")

            # When / Then
            self.assertNotIn("Combat/Trace.lua", files)
            self.assertNotIn("Combat/WindfuryTrace.lua", files)
            self.assertNotIn("Combat/WindfuryCapture.lua", files)

        # Given / When
        exclusions = (ROOT / ".pkgmeta").read_text(encoding="utf-8")

        # Then
        self.assertIn("  - Combat/Trace.lua\n", exclusions)
        self.assertIn("  - Combat/WindfuryTrace.lua\n", exclusions)
        self.assertIn("  - Combat/WindfuryCapture.lua\n", exclusions)
