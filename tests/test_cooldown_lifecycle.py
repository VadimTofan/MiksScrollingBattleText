import unittest

from tests.lua_test_runner import run_lua_test


# Describe: cooldown lifecycle.
class RuntimeAuditFixTests(unittest.TestCase):
    def test_disabled_cooldowns_cannot_restart_tracking(self):
        # Given
        script = "cooldown_disable_lifecycle.lua"
    
        # When
        result = run_lua_test(script)
    
        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_combat_transitions_preserve_item_cooldowns(self):
        # Given
        script = "cooldown_combat_lifecycle.lua"
    
        # When
        result = run_lua_test(script)
    
        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
