import unittest

from tests.lua_test_runner import run_lua_test


# Describe: outgoing spell attribution recognizes all displayed damage schools.
class SpellDamageSchoolTests(unittest.TestCase):
    def test_all_damage_schools_retain_direct_and_periodic_attribution(self):
        # Given
        script = "spell_damage_schools.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
