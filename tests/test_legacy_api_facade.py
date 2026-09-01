import unittest

from tests.lua_test_runner import run_lua_test


# Describe: legacy API compatibility
class LegacyApiFacadeTests(unittest.TestCase):
    def test_facade_routes_legacy_exports_through_safe_adapters(self):
        # Given
        script_name = "legacy_api_facade.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
