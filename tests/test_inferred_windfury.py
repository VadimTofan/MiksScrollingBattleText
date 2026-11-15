import unittest

from tests.lua_test_runner import run_lua_test


# Describe: optional icons use complete public accounting, never damage values.
class InferredWindfuryTests(unittest.TestCase):
    def test_pending_owned_reports_keep_conservative_inferred_icons(self):
        # Given owned reports, source reservations, and opaque damage values.
        script = "inferred_windfury.lua"

        # When the production inference stage observes each bounded source.
        result = run_lua_test(script)

        # Then only complete clean sources decorate their damage once.
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
