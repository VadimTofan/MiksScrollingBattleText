import unittest

from tests.lua_test_runner import run_lua_test


# Describe: the developer tab of the classic options window.
class DeveloperTabTests(unittest.TestCase):
    def test_tab_waits_for_the_debug_window_and_lists_the_generated_tables(self):
        # Given
        script_name = "developer_tab.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
