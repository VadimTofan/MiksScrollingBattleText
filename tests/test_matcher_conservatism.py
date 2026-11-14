import unittest

from tests.lua_test_runner import run_lua_test


# Describe: spell identity requires evidence beyond confirmed ownership.
class MatcherConservatismTests(unittest.TestCase):
    def test_matcher_preserves_ownership_without_speculative_identity(self):
        # Given competing casts, expired effects, and forgotten targets.
        script = "matcher_conservatism.lua"

        # When production matching receives their confirmed outcomes.
        result = run_lua_test(script)

        # Then only supported identities and timing are retained.
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
