import unittest

from tests.lua_test_runner import run_lua_test


class PeriodicDamageTests(unittest.TestCase):
    def test_locale_independent_outgoing_dot_pipeline(self):
        result = run_lua_test("periodic_damage.lua")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
