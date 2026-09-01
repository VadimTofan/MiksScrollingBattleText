import unittest

from tests.lua_test_runner import run_lua_test


# Describe: merge batching service
class BatcherServiceTests(unittest.TestCase):
    def test_batcher_combines_matching_events_and_builds_crit_trailer(self):
        # Given
        script_name = "batcher_service.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
