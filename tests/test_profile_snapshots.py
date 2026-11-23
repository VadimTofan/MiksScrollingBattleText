import unittest

from tests.lua_test_runner import run_lua_test


# Describe: changes since login can be listed, reverted and restored.
class ProfileSnapshotsTests(unittest.TestCase):
    def test_snapshots_restore_diff_revert_and_login_rules(self):
        # Given
        script_name = "profile_snapshots.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
