import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
PROFILES_FILE = REPOSITORY_ROOT / "MSBTProfiles.lua"


# Describe: health triggers under Midnight restrictions
class RestrictedHealthTriggerTests(unittest.TestCase):
    def test_health_and_mana_threshold_defaults_are_removed(self):
        # Given the default profiles for both client branches.
        source = PROFILES_FILE.read_text(encoding="utf-8-sig")

        # When inspecting the default trigger definitions.
        retired_keys = (
            "MSBT_TRIGGER_LOW_HEALTH", "MSBT_TRIGGER_LOW_MANA",
            "MSBT_TRIGGER_LOW_PET_HEALTH", "MSBT_TRIGGER_EXECUTE",
            "MSBT_TRIGGER_HAMMER_OF_WRATH",
        )

        # Then no threshold trackers are offered as built-in triggers.
        for key in retired_keys:
            self.assertNotIn(key + " = {", source)


if __name__ == "__main__":
    unittest.main()
