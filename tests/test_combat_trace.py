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

    def test_both_clients_load_the_trace_after_its_dependencies(self):
        # Given
        for manifest in ROOT.glob("MikScrollingBattleText*.toc"):
            files = manifest.read_text(encoding="utf-8-sig").replace("\\", "/")

            # When
            trace_position = files.find("Combat/Trace.lua")

            # Then
            self.assertGreater(trace_position, files.index("MSBTMain.lua"))
