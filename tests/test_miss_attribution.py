import unittest

from tests.lua_test_runner import run_lua_test


# Describe: a miss goes only to an action that can have caused it.
class MissAttributionTests(unittest.TestCase):
    def test_marks_and_shots_do_not_take_parries_that_cannot_be_theirs(self):
        # Given
        script = "miss_attribution.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
