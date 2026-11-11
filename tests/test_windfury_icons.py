import unittest

from tests.lua_test_runner import run_lua_test


# Describe: shamans use active Windfury as a physical proc best guess.
class WindfuryIconTests(unittest.TestCase):
    def test_shaman_physical_procs_use_only_an_active_windfury_fallback(self):
        # Given
        script = "windfury_icons.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
