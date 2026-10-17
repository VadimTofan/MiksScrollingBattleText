import unittest

from tests.lua_test_runner import run_lua_test


# Describe: incoming heal timer reset.
class RuntimeAuditFixTests(unittest.TestCase):
    def test_healing_displays_outside_combat_and_across_transitions(self):
        # Given
        script = "incoming_heal_combat_transitions.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_old_heal_timers_cannot_flush_replacement_batches(self):
        # Given
        script = "incoming_heal_timer_reset.lua"
    
        # When
        result = run_lua_test(script)
    
        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
