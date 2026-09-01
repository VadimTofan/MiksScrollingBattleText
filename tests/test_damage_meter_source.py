import unittest

from tests.lua_test_runner import run_lua_test


# Describe: outgoing damage-meter source component
class DamageMeterSourceTests(unittest.TestCase):
    def test_source_emits_spell_deltas_and_manages_its_ticker(self):
        # Given
        script_name = "damage_meter_source.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
