import unittest

from tests.lua_test_runner import run_lua_test


# Describe: the Events page of the new options window.
class OptionsEventsTests(unittest.TestCase):
    def test_events_page_lists_previews_and_saves_events(self):
        # Given
        script_name = "options_events.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
