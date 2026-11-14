import unittest

from tests.lua_test_runner import run_lua_test


# Describe: the General, Fonts & Colors, Sounds and Profile pages of the new options window.
class OptionsPagesTests(unittest.TestCase):
    def test_pages_save_through_the_classic_paths(self):
        # Given
        script_name = "options_pages.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
