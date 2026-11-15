import unittest

from tests.lua_test_runner import run_lua_test


# Describe: the optional inferred Windfury icon preference.
class InferredWindfuryOptionsTests(unittest.TestCase):
    def test_general_checkbox_saves_and_refreshes_only_on_forever(self):
        # Given the real General tab controls and English option text.
        script_name = "inferred_windfury_controls.lua"

        # When the preference is toggled and a different profile is selected.
        result = run_lua_test(script_name)

        # Then the checkbox reflects the active preference on Forever only.
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
