import unittest

from tests.lua_test_runner import run_lua_test


# Describe: display policy service
class DisplayServiceTests(unittest.TestCase):
    def test_service_resolves_crit_style_and_public_message_defaults(self):
        # Given
        script_name = "display_service.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
