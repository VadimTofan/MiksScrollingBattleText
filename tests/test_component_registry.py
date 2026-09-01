import unittest

from tests.lua_test_runner import run_lua_test


# Describe: component registration and lifecycle
class ComponentRegistryTests(unittest.TestCase):
    def test_registry_initializes_and_enables_components_in_registration_order(self):
        # Given
        script_name = "component_registry_order.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_registry_rejects_duplicate_component_names(self):
        # Given
        script_name = "component_registry_duplicate.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_registry_lifecycle_calls_are_idempotent(self):
        # Given
        script_name = "component_registry_idempotent.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_registry_isolates_component_lifecycle_failures(self):
        # Given
        script_name = "component_registry_failure.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
