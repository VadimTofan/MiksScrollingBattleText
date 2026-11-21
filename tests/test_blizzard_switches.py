import unittest

from tests.lua_test_runner import run_lua_test


# Describe: a switch for a client setting mirrors the client until set, then the profile's value is forced
class BlizzardSwitchTests(unittest.TestCase):
    def test_switches_mirror_until_set_and_are_forced_once_set(self):
        # Given
        script = "blizzard_switches.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
