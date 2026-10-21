import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RESOURCE_EVENTS = (
    "NOTIFICATION_POWER_GAIN", "NOTIFICATION_POWER_LOSS",
    "NOTIFICATION_ALT_POWER_GAIN", "NOTIFICATION_ALT_POWER_LOSS",
    "NOTIFICATION_CHI_CHANGE", "NOTIFICATION_CHI_FULL",
    "NOTIFICATION_AC_CHANGE", "NOTIFICATION_AC_FULL",
    "NOTIFICATION_CP_GAIN", "NOTIFICATION_CP_FULL",
    "NOTIFICATION_HOLY_POWER_CHANGE", "NOTIFICATION_HOLY_POWER_FULL",
    "NOTIFICATION_ESSENCE_CHANGE", "NOTIFICATION_ESSENCE_FULL",
)


# Describe: removed resource notifications have no defaults or settings UI.
class ResourceNotificationRemovalTests(unittest.TestCase):
    def test_resource_gains_have_defaults_and_a_configurable_event(self):
        # Given both client defaults and the notification settings UI.
        profiles = (ROOT / "MSBTProfiles.lua").read_text(encoding="utf-8-sig")
        tabs = (ROOT / "MSBTOptions" / "MSBTOptionsTabs.lua").read_text(
            encoding="utf-8-sig"
        )
        locale = (
            ROOT / "MSBTOptions" / "Localization" / "localization.lua"
        ).read_text(encoding="utf-8-sig")

        # When checking the supported resource-gain event.
        event = "NOTIFICATION_RESOURCE_GAIN"

        # Then both clients and the settings UI offer the event.
        self.assertEqual(profiles.count(event + " = {"), 2)
        self.assertEqual(profiles.count('message = "%a - %p"'), 2)
        self.assertIn('EventsTab_AddEvent(category, "' + event + '"', tabs)
        self.assertIn('obj["' + event + '"]', locale)

    def test_resource_notifications_are_not_offered_on_either_client(self):
        # Given both client defaults and the notification settings UI.
        paths = [
            ROOT / "MSBTProfiles.lua",
            ROOT / "MSBTOptions" / "MSBTOptionsTabs.lua",
        ]
        paths.extend((ROOT / "MSBTOptions" / "Localization").glob("*.lua"))

        # When inspecting the events offered to users.
        for path in paths:
            source = path.read_text(encoding="utf-8-sig")

            # Then no removed resource event is configurable or translated.
            for event in RESOURCE_EVENTS:
                self.assertTrue(event not in source, f"{path.name}: {event}")


if __name__ == "__main__":
    unittest.main()
