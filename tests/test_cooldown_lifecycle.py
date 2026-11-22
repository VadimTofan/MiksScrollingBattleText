import unittest

from tests.lua_test_runner import run_lua_test


# Describe: cooldown lifecycle.
class RuntimeAuditFixTests(unittest.TestCase):
    def test_player_ability_ready_plays_original_click_once(self):
        # Given an opt-in alert with a known player ability and the bundled sound.
        script = "spell_cooldown_alert.lua"

        # When the spell enters and leaves a confirmed cooldown.
        result = run_lua_test(script)

        # Then the ability clicks once and unrelated cooldowns stay quiet.
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

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
