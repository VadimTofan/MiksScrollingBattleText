import unittest

from tests.lua_test_runner import run_lua_test


# Describe: recorded periodic overlap preserves reports without false spell IDs.
class RecordedSpellIdentityTests(unittest.TestCase):
    def test_fixed_target_overlap_keeps_only_supported_spell_names(self):
        # Given sanitized public events and opaque amounts from a real capture.
        script = "recorded_spell_identity.lua"

        # When the real reader, matcher, presentation, and batcher replay them.
        result = run_lua_test(script)

        # Then ownership survives and any spell name agrees with offline truth.
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
