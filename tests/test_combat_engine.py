import unittest

from tests.lua_test_runner import run_lua_test


# Describe: the adapted engine feeds MSBT without replacing its display.
class CombatEngineTests(unittest.TestCase):
    def test_setup_waits_for_saved_filters_and_stays_quiet_after_reload(self):
        # Given
        script = "combat_setup_lifecycle.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_channel_hits_keep_their_spell_until_the_channel_stops(self):
        # Given
        script = "channel_attribution.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_cleanup_avoids_allocation_churn_during_repeated_combat_events(self):
        # Given
        script = "combat_cleanup_allocations.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_matching_window_reuses_samples_and_refreshes_when_they_change(self):
        # Given
        script = "combat_pair_window.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_expired_target_timings_release_keys_and_preserve_active_rhythms(self):
        # Given
        script = "target_cache_lifecycle.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_cast_histories_expire_without_recasting_the_same_spell(self):
        # Given
        script = "cast_history_lifecycle.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_incoming_healer_notices_pair_in_either_order_within_200_ms(self):
        # Given
        script = "incoming_healer_pairing.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

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
