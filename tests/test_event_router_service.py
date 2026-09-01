import unittest

from tests.lua_test_runner import run_lua_test


# Describe: parser event routing service
class EventRouterServiceTests(unittest.TestCase):
    def test_router_dispatches_registered_event_handlers(self):
        # Given
        script_name = "event_router_service.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
