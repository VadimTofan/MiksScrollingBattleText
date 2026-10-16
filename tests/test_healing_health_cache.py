import unittest

from tests.lua_test_runner import run_lua_test


# Describe: overheal estimates require a known pre-heal health value.
class HealingHealthCacheTests(unittest.TestCase):
    def test_missing_health_history_preserves_the_heal(self):
        # Given
        script = "healing_health_cache.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
