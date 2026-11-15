import unittest

from tests.lua_test_runner import run_lua_test


# Describe: optional accounting observes outcomes without spending them again.
class MineOutcomeReceiptTests(unittest.TestCase):
    def test_receipts_follow_only_consumed_unambiguous_outcomes(self):
        # Given casts, swings, and opaque damage with accounting on and off.
        script = "mine_outcome_receipts.lua"

        # When the existing attribution paths consume their outcomes.
        result = run_lua_test(script)

        # Then receipts expose public metadata without changing attribution.
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
