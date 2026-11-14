import unittest

from tests.lua_test_runner import run_lua_test


# Describe: complete reader replays preserve ownership without invented identity.
class OutgoingCaptureReplayTests(unittest.TestCase):
    def test_captured_timings_keep_opaque_hits_and_typed_confirmations(self):
        # Given captured event timing, real spell metadata, and opaque amounts.
        script = "outgoing_capture_replays.lua"

        # When the real reader, log filter, presentation, and batcher replay it.
        result = run_lua_test(script)

        # Then owned hits survive while identity and confirmation budgets hold.
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
