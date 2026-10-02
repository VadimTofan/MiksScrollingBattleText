import unittest

from tests.lua_test_runner import run_lua_test


# Describe: animation memory lifecycle.
class RuntimeAuditFixTests(unittest.TestCase):
    def test_finished_animations_release_scroll_area_tables(self):
        # Given
        script = "animation_memory_lifecycle.lua"
    
        # When
        result = run_lua_test(script)
    
        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
