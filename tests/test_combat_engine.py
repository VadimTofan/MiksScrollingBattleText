import unittest

from tests.lua_test_runner import run_lua_test


# Describe: the adapted engine feeds MSBT without replacing its display.
class CombatEngineTests(unittest.TestCase):
    def test_filter_changes_are_saved_only_for_the_next_session(self):
        # Given
        script = "combat_log_filter.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_real_main_uses_engine_on_retail_and_forever(self):
        # Given
        script = "combat_main_runtime.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_engine_reads_spells_hits_heals_and_alerts_with_safe_lifecycle(self):
        # Given
        script = "combat_engine.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_engine_records_keep_msbt_event_settings_and_restricted_values(self):
        # Given
        script = "combat_presentation.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
