import unittest

from tests.lua_test_runner import run_lua_test


# Describe: confirmed Windfury procs inherit the active weapon enchant's icon.
class WindfuryIconTests(unittest.TestCase):
    def test_active_windfury_enchants_identify_physical_procs_safely(self):
        # Given
        script = "windfury_icons.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
