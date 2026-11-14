import unittest

from tests.lua_test_runner import run_lua_test


# Describe: grouping can preserve unnamed proc candidates without naming them.
class CandidateBatchingTests(unittest.TestCase):
    def test_unnamed_proc_candidates_keep_separate_restricted_amounts(self):
        # Given / When
        result = run_lua_test("candidate_batching.lua")

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
