import unittest

from tests.lua_test_runner import run_lua_test


# Describe: event throttling service
class ThrottlerServiceTests(unittest.TestCase):
    def test_throttler_queues_repeated_events_and_releases_after_window(self):
        # Given
        script_name = "throttler_service.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
