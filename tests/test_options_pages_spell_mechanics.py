import unittest

from tests.lua_test_runner import run_lua_test


# Describe: the General page of the new options window builds the client text switches only when it can.
class OptionsPagesSpellMechanicsTests(unittest.TestCase):
    def test_no_switch_without_the_profiles_functions(self):
        # Given
        script_name = "options_pages_without_spell_mechanics.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_no_switch_without_the_texts(self):
        # Given
        script_name = "options_pages_without_spell_mechanics_text.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_no_switch_when_the_client_has_neither_setting(self):
        # Given
        script_name = "options_pages_no_client_spell_mechanics.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_blizzard_switches_show_the_client_and_cancel_restores_them(self):
        # Given
        script_name = "options_pages_blizzard_switches.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_reputation_and_honor_switches_without_the_get_function(self):
        # Given
        script_name = "options_pages_text_switches_get.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_reputation_and_honor_switches_without_the_set_function(self):
        # Given
        script_name = "options_pages_text_switches_set.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_reputation_and_honor_switches_without_the_take_function(self):
        # Given
        script_name = "options_pages_text_switches_take.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_reputation_and_honor_switches_without_the_restore_function(self):
        # Given
        script_name = "options_pages_text_switches_restore.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_reputation_and_honor_switches_without_the_texts(self):
        # Given
        script_name = "options_pages_text_switches_texts.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_reputation_and_honor_switches_when_the_client_has_neither_setting(self):
        # Given
        script_name = "options_pages_text_switches_client.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_reputation_and_honor_switches_beside_missing_effect_switches(self):
        # Given
        script_name = "options_pages_text_switches_only.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


    def test_blizzard_outgoing_stays_on_its_profile_option_without_the_numbers_text(self):
        # Given
        script_name = "options_pages_blizzard_outgoing_without_numbers.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
