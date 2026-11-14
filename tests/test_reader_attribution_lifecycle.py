import unittest

from tests.lua_test_runner import run_lua_test


# Describe: outgoing evidence stays with its original target and cast.
class ReaderAttributionLifecycleTests(unittest.TestCase):
    def test_target_lifetimes_and_cast_recipients_preserve_owned_reports(self):
        # Given opaque reports and public cast/target lifecycle events.
        script = "reader_attribution_lifecycle.lua"

        # When the real reader and matcher process each event sequence.
        result = run_lua_test(script)

        # Then ownership and spell identity never cross creature lifetimes.
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
