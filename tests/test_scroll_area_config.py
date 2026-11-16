import unittest

from tests.lua_test_runner import run_lua_test


# Describe: the classic scroll area configuration.
class ScrollAreaConfigTests(unittest.TestCase):
    def test_configuration_lists_styles_and_saves_every_field(self):
        # Given
        script_name = "scroll_area_config.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
