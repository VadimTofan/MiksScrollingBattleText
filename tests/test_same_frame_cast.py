import unittest

from tests.lua_test_runner import run_lua_test


# Describe: a hit goes to the cast in its own frame before older casts.
class SameFrameCastTests(unittest.TestCase):
    def test_a_cast_in_the_hits_frame_comes_before_older_casts(self):
        # Given
        script = "same_frame_cast.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
