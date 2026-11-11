import unittest

from tests.lua_test_runner import run_lua_test


# Describe: outgoing hit batching component
class OutgoingBatcherTests(unittest.TestCase):
    def test_windfury_stacks_delayed_and_restricted_hits(self):
        # Given Windfury bursts with readable and restricted damage.
        script_name = "windfury_stacking.lua"

        # When delayed hits arrive with stacking enabled or disabled.
        result = run_lua_test(script_name)

        # Then one burst preserves its damage, settings, and reset behavior.
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_batcher_stacks_hits_and_resets_pending_output(self):
        # Given
        script_name = "outgoing_batcher.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
