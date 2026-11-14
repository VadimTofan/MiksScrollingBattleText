import unittest

from tests.lua_test_runner import run_lua_test


# Describe: owned damage stays visible independently of spell identity.
class OwnershipPresentationTests(unittest.TestCase):
    def test_owned_unnamed_damage_preserves_rendering_and_candidate_metadata(self):
        # Given
        script = "ownership_presentation.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_diagnostics_separate_candidate_ownership_and_identity(self):
        # Given
        script = "ownership_diagnostics.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
