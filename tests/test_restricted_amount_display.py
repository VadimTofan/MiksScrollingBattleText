import unittest

from tests.lua_test_runner import run_lua_test


# Describe: restricted amount display support.
class RestrictedAmountDisplayTests(unittest.TestCase):
    def test_opaque_amount_reaches_the_display_as_a_separate_argument(self):
        # Given
        script = "restricted_amount_display.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
