import unittest

from tests.lua_test_runner import run_lua_test


# Describe: profile saved-variable storage
class ProfileStoreTests(unittest.TestCase):
    def test_store_preserves_legacy_saved_variable_contracts(self):
        # Given
        script_name = "profile_store.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
