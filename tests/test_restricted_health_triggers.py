import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
PROFILES_FILE = REPOSITORY_ROOT / "MSBTProfiles.lua"


# Describe: health triggers under Midnight restrictions
class RestrictedHealthTriggerTests(unittest.TestCase):
    def test_low_health_and_low_mana_defaults_are_disabled(self):
        # Given
        source = PROFILES_FILE.read_text(encoding="utf-8-sig")

        # When
        low_health_blocks = source.split("MSBT_TRIGGER_LOW_HEALTH = {")[1:]
        low_mana_blocks = source.split("MSBT_TRIGGER_LOW_MANA = {")[1:]

        # Then
        self.assertEqual(len(low_health_blocks), 2)
        self.assertEqual(len(low_mana_blocks), 2)
        for block in low_health_blocks:
            self.assertIn("disabled", block.split("},", 1)[0])
        for block in low_mana_blocks:
            self.assertIn("disabled", block.split("},", 1)[0])


if __name__ == "__main__":
    unittest.main()
