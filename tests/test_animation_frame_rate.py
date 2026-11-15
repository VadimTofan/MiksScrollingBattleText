import unittest

from tests.lua_test_runner import run_lua_test


# Describe: scrolling text at high frame rates.
class AnimationFrameRateTests(unittest.TestCase):
    def test_text_moves_evenly_on_every_frame(self):
        # Given
        script = "animation_frame_rate.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
