import unittest

from tests.lua_test_runner import run_lua_test


# Describe: Blizzard output categories remain independent of MSBT's event feed.
class CombatTextCategoryTests(unittest.TestCase):
    def test_blizzard_category_switches_preserve_the_shared_event_feed(self):
        # Given
        script = "blizzard_text_categories.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
