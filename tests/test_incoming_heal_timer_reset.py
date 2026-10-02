import unittest

from tests.lua_test_runner import run_lua_test


# Describe: incoming heal timer reset.
class RuntimeAuditFixTests(unittest.TestCase):
    def test_old_heal_timers_cannot_flush_replacement_batches(self):
        # Given
        script = "incoming_heal_timer_reset.lua"
    
        # When
        result = run_lua_test(script)
    
        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
