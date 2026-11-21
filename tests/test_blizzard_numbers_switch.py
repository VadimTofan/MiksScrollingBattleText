import unittest

from tests.lua_test_runner import run_lua_test


# Describe: the numbers over targets follow their own switch, with every client setting of the group
class BlizzardNumbersSwitchTests(unittest.TestCase):
    def test_numbers_follow_their_switch_and_not_the_master(self):
        # Given
        script = "blizzard_numbers_switch.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
