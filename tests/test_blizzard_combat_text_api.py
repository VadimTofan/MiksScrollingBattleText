import unittest

from tests.lua_test_runner import run_lua_test


# Describe: Blizzard combat-text CVar boundary
class BlizzardCombatTextApiTests(unittest.TestCase):
    def test_adapter_writes_all_cvars_only_out_of_combat(self):
        # Given
        script_name = "blizzard_combat_text_api.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
