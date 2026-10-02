import unittest

from tests.lua_test_runner import run_lua_test


# Describe: throttler cleanup.
class RuntimeAuditFixTests(unittest.TestCase):
    def test_expired_throttle_keys_are_removed(self):
        # Given
        script = "throttler_cleanup.lua"
    
        # When
        result = run_lua_test(script)
    
        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
