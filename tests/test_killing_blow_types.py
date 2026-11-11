import unittest

from tests.lua_test_runner import run_lua_test


# Describe: killing blows route only when the dying victim is identifiable.
class KillingBlowTypeTests(unittest.TestCase):
    def test_reader_keeps_player_npc_and_ambiguous_victims_separate(self):
        # Given
        script = "killing_blow_types.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_unknown_kills_share_npc_settings_without_enabling_player_alerts(self):
        # Given
        script = "killing_blow_presentation.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
