import unittest

from tests.lua_test_runner import run_lua_test


# Describe: custom event sounds restored after the component rewrite.
class CustomSoundTests(unittest.TestCase):
    def test_options_add_preview_save_clear_and_reopen_event_sounds(self):
        # Given
        script_name = "custom_sound_options.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_registered_and_saved_sounds_resolve_and_play_safely(self):
        # Given
        script_name = "custom_sounds.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_event_sounds_follow_display_and_profile_settings(self):
        # Given
        script_name = "event_sounds.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
