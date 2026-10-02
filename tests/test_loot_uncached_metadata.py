import unittest

from tests.lua_test_runner import run_lua_test


# Describe: loot uncached metadata.
class RuntimeAuditFixTests(unittest.TestCase):
    def test_uncached_loot_uses_a_safe_name(self):
        # Given
        script = "loot_uncached_metadata.lua"
    
        # When
        result = run_lua_test(script)
    
        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
