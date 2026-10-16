import unittest

from tests.lua_test_runner import run_lua_test


# Describe: combat log ownership requires matching evidence.
class CombatLogMessageSourceTests(unittest.TestCase):
    def test_unknown_lines_cannot_claim_actions_and_stop_clears_state(self):
        # Given
        script = "combat_log_message_source.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
