import unittest

from tests.lua_test_runner import run_lua_test


# Describe: the combat reader avoids aura APIs while access is restricted.
class AuraAccessTests(unittest.TestCase):
    def test_restricted_auras_are_skipped_and_readable_auras_still_work(self):
        # Given
        script = "aura_access.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
