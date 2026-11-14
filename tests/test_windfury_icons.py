import unittest

from tests.lua_test_runner import run_lua_test


# Describe: shamans use active Windfury as a physical proc best guess.
class WindfuryIconTests(unittest.TestCase):
    def test_recorded_windfury_cooldowns_need_a_matching_player_melee_frame(self):
        # Given
        script = "windfury_cooldown_notice.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_explicit_windfury_casts_display_separate_proc_notices(self):
        # Given
        script = "windfury_notice.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_shaman_physical_procs_use_only_an_active_windfury_fallback(self):
        # Given
        script = "windfury_icons.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
