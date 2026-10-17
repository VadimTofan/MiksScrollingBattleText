import unittest

from tests.lua_test_runner import run_lua_test


# Describe: embedded settings preserve the existing options workflows.
class SettingsIntegrationTests(unittest.TestCase):
    def test_category_switching_and_configuration_return(self):
        # Given
        script = "settings_integration.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
