import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
TRIGGERS_FILE = REPOSITORY_ROOT / "MSBTTriggers.lua"


# Describe: non-CLEU trigger event registration
class NonCleuTriggerRegistrationTests(unittest.TestCase):
    def test_health_and_power_events_register_without_cleu(self):
        # Given
        source = TRIGGERS_FILE.read_text(encoding="utf-8-sig")

        # When
        registration_block = source.split(
            'eventFrame:SetScript("OnEvent", OnEvent)', 1
        )[1].split("CreateCaptureFuncs()", 1)[0]

        # Then
        self.assertEqual(registration_block.count("SafeRegisterUnitEvent("), 2)
        self.assertIn('"UNIT_HEALTH"', registration_block)
        self.assertIn('"UNIT_POWER_UPDATE"', registration_block)
        self.assertNotIn("COMBAT_LOG_EVENT_UNFILTERED", registration_block)


if __name__ == "__main__":
    unittest.main()
