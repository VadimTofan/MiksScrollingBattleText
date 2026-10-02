import unittest

from tests.lua_test_runner import run_lua_test


# Describe: portable profile exports and safe imports.
class ProfileTransferTests(unittest.TestCase):
    def test_profiles_round_trip_without_overwriting_existing_data(self):
        # Given
        script_name = "profile_transfer.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_profile_actions_transfer_real_defaults_and_activate_imports(self):
        # Given
        script_name = "profile_transfer_integration.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_transfer_dialog_preserves_failed_input_and_refreshes_profiles(self):
        # Given
        script_name = "profile_transfer_dialog.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
