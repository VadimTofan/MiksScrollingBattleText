import unittest

from tests.lua_test_runner import run_lua_test


# Describe: internal event dispatch
class EventBusTests(unittest.TestCase):
    def test_event_bus_orders_handlers_and_unsubscribes_by_owner(self):
        # Given
        script_name = "event_bus_subscriptions.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_event_bus_isolates_handler_failures(self):
        # Given
        script_name = "event_bus_failure.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
