import unittest

from tests.lua_test_runner import run_lua_test


# Describe: outgoing spell attribution recognizes all displayed damage schools.
class SpellDamageSchoolTests(unittest.TestCase):
    def test_chinese_spell_schools_and_helpful_spells_constrain_matching(self):
        # Given
        script = "localized_spell_facts.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_all_damage_schools_retain_direct_and_periodic_attribution(self):
        # Given
        script = "spell_damage_schools.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
