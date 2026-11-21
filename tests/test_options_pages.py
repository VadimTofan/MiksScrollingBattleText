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

    def test_custom_font_registers_without_the_classic_general_tab(self):
        # Given
        script_name = "options_pages_custom_font.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_developer_page_shows_while_the_debug_window_is_loaded(self):
        # Given
        script_name = "options_pages_developer_offered.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_developer_page_says_when_no_table_has_registered(self):
        # Given
        script_name = "options_pages_developer_empty.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_no_developer_page_without_the_debug_window(self):
        # Given
        script_name = "options_pages_developer_not_offered.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_no_developer_page_without_the_classic_tabs_share(self):
        # Given
        script_name = "options_pages_developer_absent.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
