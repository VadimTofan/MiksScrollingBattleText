import unittest

from tests.lua_test_runner import run_lua_test


# Describe: direct spell identities require a distinct, eligible candidate.
class DirectSpellMatchingTests(unittest.TestCase):
    def test_candidates_preserve_ownership_without_guessing_spell_identity(self):
        # Given overlapping casts and readable or unavailable hit amounts.
        script = "direct_spell_matching.lua"

        # When the real attribution engine compares the candidates.
        result = run_lua_test(script)

        # Then clear matches retain identity and ambiguous hits cannot learn it.
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
