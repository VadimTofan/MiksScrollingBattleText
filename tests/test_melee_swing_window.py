import unittest

from tests.lua_test_runner import run_lua_test


# Describe: learned swing windows adapt to each hand's observed delays.
class MeleeSwingWindowTests(unittest.TestCase):
    def test_variable_delays_widen_the_window_while_stable_delays_stay_tight(self):
        # Given
        script = "melee_swing_window.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
