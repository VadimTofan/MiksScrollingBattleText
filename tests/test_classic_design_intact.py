import unittest

from tests.lua_test_runner import run_lua_test


# Describe: the classic options window is untouched by the new options window.
class ClassicDesignIntactTests(unittest.TestCase):
    def test_classic_window_looks_the_same_after_the_new_window_was_used(self):
        # Given
        script_name = "classic_design_intact.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
