import unittest

from tests.lua_test_runner import run_lua_test


# Describe: combat text CVar writes.
class CombatTextCVarWriteTests(unittest.TestCase):
    def test_settings_are_written_only_when_they_change(self):
        # Given
        script = "combat_text_cvar_writes.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
