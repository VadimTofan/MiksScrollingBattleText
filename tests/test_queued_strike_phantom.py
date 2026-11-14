import unittest

from tests.lua_test_runner import run_lua_test


# Describe: a queued strike's zero report and swing are not shown as hits.
class QueuedStrikePhantomTests(unittest.TestCase):
    def test_zero_report_and_strike_swing_are_not_given_to_the_pet(self):
        # Given
        script = "queued_strike_phantom.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
