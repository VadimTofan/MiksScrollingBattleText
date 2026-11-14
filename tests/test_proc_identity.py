import unittest

from tests.lua_test_runner import run_lua_test


# Describe: active weapon effects are candidate evidence, not spell identity.
class ProcIdentityTests(unittest.TestCase):
    def test_active_effects_never_supply_an_authoritative_proc_name(self):
        # Given / When
        result = run_lua_test("proc_identity.lua")

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
