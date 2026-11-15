import unittest

from tests.lua_test_runner import run_lua_test


# Describe: diagnostic accounting preserves source and ownership uncertainty.
class SwingAccountingTests(unittest.TestCase):
    def test_observed_outcomes_use_bounded_public_source_evidence(self):
        # Given a pure ledger with public metadata and opaque control values.
        script = "swing_accounting.lua"

        # When observations are replayed without production attribution.
        result = run_lua_test(script)

        # Then reservations, exclusions, ambiguity, and limits stay explicit.
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
