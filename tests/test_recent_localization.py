import unittest

from tests.lua_test_runner import run_lua_test


# Describe: recently added UI and notifications use each supported locale.
class RecentLocalizationTests(unittest.TestCase):
    def test_recent_features_have_translations_and_preserve_format_tokens(self):
        # Given
        script = "recent_localization.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
