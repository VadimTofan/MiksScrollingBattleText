import unittest

from tests.lua_test_runner import run_lua_test


# Describe: selecting a profile that was selected before
class ProfileReselectTests(unittest.TestCase):
    def test_a_profile_selected_before_can_be_selected_again(self):
        # Given
        script_name = "profile_reselect.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
