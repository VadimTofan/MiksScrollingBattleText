import unittest

from tests.lua_test_runner import run_lua_test


# Describe: scroll-area service
class ScrollAreasServiceTests(unittest.TestCase):
    def test_service_resolves_profile_areas_and_group_suppression(self):
        # Given
        script_name = "scroll_areas_service.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
