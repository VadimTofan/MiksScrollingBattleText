import unittest

from tests.lua_test_runner import run_lua_test


# Describe: shots worded as ranged damage or missiles deal physical damage at once.
class HunterShotDescriptionTests(unittest.TestCase):
    def test_aimed_shot_and_multi_shot_take_their_own_hits(self):
        # Given
        script = "hunter_shot_descriptions.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
