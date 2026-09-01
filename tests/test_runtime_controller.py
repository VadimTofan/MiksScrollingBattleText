import unittest

from tests.lua_test_runner import run_lua_test


# Describe: runtime configuration controller
class RuntimeControllerTests(unittest.TestCase):
    def test_controller_applies_addon_and_group_combat_text_policy(self):
        # Given
        script_name = "runtime_controller.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
