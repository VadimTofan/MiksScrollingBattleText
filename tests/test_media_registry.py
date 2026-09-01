import unittest

from tests.lua_test_runner import run_lua_test


# Describe: media registry
class MediaRegistryTests(unittest.TestCase):
    def test_registry_loads_shared_and_saved_media(self):
        # Given
        script_name = "media_registry.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
