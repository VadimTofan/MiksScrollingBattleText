import unittest

from tests.lua_test_runner import run_lua_test


# Describe: the new options window wears Blizzard's options art where the client has it.
class OptionsBlizzardLookTests(unittest.TestCase):
    def test_new_window_wears_blizzard_art_where_the_client_has_it(self):
        # Given
        script_name = "options_blizzard_look.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
