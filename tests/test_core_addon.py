import unittest

from tests.lua_test_runner import run_lua_test


# Describe: core addon bootstrap
class CoreAddonTests(unittest.TestCase):
    def test_bootstrap_exposes_shared_context_and_component_registration(self):
        # Given
        script_name = "core_addon_bootstrap.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
