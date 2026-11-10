import unittest

from tests.lua_test_runner import run_lua_test


# Describe: the learned swing window stays open for a slow weapon's hits.
class MeleeSwingWindowTests(unittest.TestCase):
    def test_learned_window_never_closes_inside_the_unlearned_one(self):
        # Given
        script = "melee_swing_window.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
