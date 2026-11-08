import unittest

from tests.lua_test_runner import run_lua_test


# Describe: an active Windfury enchant cannot identify a physical proc.
class WindfuryIconTests(unittest.TestCase):
    def test_active_enchants_do_not_supply_unproven_damage_identities(self):
        # Given
        script = "windfury_icons.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
