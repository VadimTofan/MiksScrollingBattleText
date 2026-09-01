import unittest

from tests.lua_test_runner import run_lua_test


# Describe: outgoing hit batching component
class OutgoingBatcherTests(unittest.TestCase):
    def test_batcher_stacks_hits_and_resets_pending_output(self):
        # Given
        script_name = "outgoing_batcher.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
