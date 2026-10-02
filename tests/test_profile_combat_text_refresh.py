import unittest

from tests.lua_test_runner import run_lua_test


# Describe: profile changes respect the combat-text client boundary
class ProfileCombatTextRefreshTests(unittest.TestCase):
    def test_refresh_is_skipped_on_modern_clients(self):
        # Given
        script_name = "profile_combat_text_refresh.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
