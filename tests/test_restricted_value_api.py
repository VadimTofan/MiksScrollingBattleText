import unittest

from tests.lua_test_runner import run_lua_test


# Describe: restricted Blizzard value access
class RestrictedValueApiTests(unittest.TestCase):
    def test_adapter_accepts_public_values_and_rejects_secrets(self):
        # Given
        script_name = "restricted_value.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
