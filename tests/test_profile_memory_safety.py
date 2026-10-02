import unittest

from tests.lua_test_runner import run_lua_test


# Describe: bounded profile decoding and trigger lifecycle cleanup.
class ProfileMemorySafetyTests(unittest.TestCase):
    def test_decompression_stops_at_the_output_limit(self):
        # Given
        script_name = "profile_decompression_limit.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_trigger_refresh_releases_removed_trigger_tables(self):
        # Given
        script_name = "trigger_memory_lifecycle.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
