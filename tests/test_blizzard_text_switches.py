import unittest

from tests.lua_test_runner import run_lua_test


# Describe: the client's own texts for effects on targets, reputation and honor have switches and boxes
class BlizzardTextSwitchTests(unittest.TestCase):
    def test_effect_and_character_texts_are_read_and_written_through_their_switches(self):
        # Given
        script = "blizzard_text_switches.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_general_tab_shows_a_box_for_each_text_the_client_has(self):
        # Given
        script = "blizzard_text_boxes.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
