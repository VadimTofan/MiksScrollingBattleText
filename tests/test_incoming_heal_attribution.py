import unittest

from tests.lua_test_runner import run_lua_test


# Describe: incoming heal attribution.
class IncomingHealAttributionTests(unittest.TestCase):
    def test_heals_use_their_frame_cast_and_show_full_overheals(self):
        # Given
        script = "incoming_heal_attribution.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
