import unittest

from tests.lua_test_runner import run_lua_test


# Describe: a pet's swing shows the pet's icon instead of the player's weapon.
class PetSwingIconTests(unittest.TestCase):
    def test_pet_melee_takes_the_pet_icon_and_nothing_else_does(self):
        # Given
        script = "pet_swing_icon.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
