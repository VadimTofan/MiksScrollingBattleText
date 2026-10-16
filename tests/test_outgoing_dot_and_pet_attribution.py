import unittest

from tests.lua_test_runner import run_lua_test


# Describe: outgoing DoT and pet attribution.
class OutgoingDotAndPetAttributionTests(unittest.TestCase):
    def test_solo_dot_ticks_and_pet_hits_are_attributed(self):
        # Given
        script = "outgoing_dot_and_pet_attribution.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
