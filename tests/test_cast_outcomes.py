import unittest

from tests.lua_test_runner import run_lua_test


# Describe: each cast spends only its supported direct outcomes.
class CastOutcomeTests(unittest.TestCase):
    def test_cast_outcomes_and_confirmed_unknown_identity(self):
        # Given direct, area, projectile, and mixed direct/periodic casts.
        script = "cast_outcomes.lua"

        # When the attribution engine receives their outcomes.
        result = run_lua_test(script)

        # Then consumption and ownership remain independent.
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
