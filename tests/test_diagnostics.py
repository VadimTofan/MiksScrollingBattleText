import unittest

from tests.lua_test_runner import run_lua_test


# Describe: component diagnostics
class DiagnosticsTests(unittest.TestCase):
    def test_diagnostics_identifies_component_and_operation(self):
        # Given
        script_name = "diagnostics_message.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
