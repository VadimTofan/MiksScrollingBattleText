import unittest

from tests.lua_test_runner import run_lua_test


# Describe: combat-text formatting service
class FormatterServiceTests(unittest.TestCase):
    def test_formatter_preserves_amount_tokens_names_and_damage_colors(self):
        # Given
        script_name = "formatter_service.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
