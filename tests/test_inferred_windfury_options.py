import unittest

from tests.lua_test_runner import run_lua_test


# Describe: baseline inferred Windfury icons.
class InferredWindfuryOptionsTests(unittest.TestCase):
    def test_inference_is_automatic_only_for_forever_shamans(self):
        # Given every class, both clients, and retired profile preferences.
        script_name = "windfury_class_defaults.lua"

        # When the engine applies its inference policy.
        result = run_lua_test(script_name)

        # Then only Forever Shamans get inference without opting in.
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_general_has_no_inferred_windfury_checkbox(self):
        # Given the real General tab controls and English option text.
        script_name = "inferred_windfury_controls.lua"

        # When General is created and populated on both clients.
        result = run_lua_test(script_name)

        # Then the retired checkbox and its locale text are absent.
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
