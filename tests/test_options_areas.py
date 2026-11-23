import unittest

from tests.lua_test_runner import run_lua_test


# Describe: the Scroll Areas page of the new options window.
class OptionsAreasTests(unittest.TestCase):
    def test_areas_page_lists_sketches_and_saves_areas(self):
        # Given
        script_name = "options_areas.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
