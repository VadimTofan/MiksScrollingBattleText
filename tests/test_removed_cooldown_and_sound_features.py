import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]


# Describe: cooldown tracking and bundled alerts remain removed.
class RemovedCooldownAndSoundFeatureTests(unittest.TestCase):
    def test_runtime_and_options_no_longer_expose_removed_features(self):
        # Given
        toc = (REPOSITORY_ROOT / "MikScrollingBattleText.toc").read_text(
            encoding="utf-8-sig"
        )
        profiles = (REPOSITORY_ROOT / "MSBTProfiles.lua").read_text(
            encoding="utf-8-sig"
        )
        options = (
            REPOSITORY_ROOT / "MSBTOptions" / "MSBTOptionsTabs.lua"
        ).read_text(encoding="utf-8-sig")

        # When / Then
        self.assertNotIn("MSBTCooldowns.lua", toc)
        self.assertNotIn("ItemCooldownTracker.lua", toc)
        self.assertNotIn("SoundDebugger.lua", toc)
        self.assertNotIn("CooldownsTab_OnShow", options)
        self.assertNotIn("soundFile", profiles)
        self.assertNotIn("NOTIFICATION_ITEM_COOLDOWN", profiles)

    def test_bundled_sound_assets_are_removed(self):
        # Given / When
        sounds_directory = REPOSITORY_ROOT / "Sounds"

        # Then
        self.assertFalse(sounds_directory.exists())


if __name__ == "__main__":
    unittest.main()
