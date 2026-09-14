import unittest
from pathlib import Path

from tests.lua_test_runner import run_lua_test


ROOT = Path(__file__).resolve().parents[1]


# Describe: bundled alerts and item cooldown notifications.
class RestoredCooldownAndSoundFeatureTests(unittest.TestCase):
    def test_item_use_reports_ready_after_cooldown(self):
        # Given
        script_name = "item_cooldown_tracker.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_only_cooldown_sound_is_bundled(self):
        # Given
        media = (ROOT / "MSBTMedia.lua").read_text(encoding="utf-8-sig")

        # When / Then
        self.assertIn("MSBT Cooldown", media)
        self.assertTrue((ROOT / "Sounds" / "Cooldown.ogg").is_file())
        for name, file in (
            ("MSBT Low Health", "LowHealth.ogg"),
            ("MSBT Low Mana", "LowMana.ogg"),
        ):
            self.assertNotIn(name, media)
            self.assertFalse((ROOT / "Sounds" / file).exists())

    def test_item_cooldown_is_loaded_with_default_notification(self):
        # Given
        toc = (ROOT / "MikScrollingBattleText.toc").read_text(
            encoding="utf-8-sig"
        )
        profiles = (ROOT / "MSBTProfiles.lua").read_text(
            encoding="utf-8-sig"
        )

        # When / Then
        self.assertIn("Components\\ItemCooldownTracker.lua", toc)
        self.assertIn("MSBTCooldowns.lua", toc)
        self.assertIn("NOTIFICATION_ITEM_COOLDOWN", profiles)

    def test_item_ready_notification_has_event_settings(self):
        # Given
        options = (ROOT / "MSBTOptions" / "MSBTOptionsTabs.lua").read_text(
            encoding="utf-8-sig"
        )
        locale = (
            ROOT / "MSBTOptions" / "Localization" / "localization.lua"
        ).read_text(encoding="utf-8-sig")

        # When / Then
        self.assertIn(
            'EventsTab_AddEvent(category, "NOTIFICATION_ITEM_COOLDOWN"',
            options,
        )
        self.assertIn('obj["NOTIFICATION_ITEM_COOLDOWN"]', locale)


if __name__ == "__main__":
    unittest.main()
