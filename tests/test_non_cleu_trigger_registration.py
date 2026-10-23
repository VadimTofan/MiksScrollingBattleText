import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
TRIGGERS_FILE = REPOSITORY_ROOT / "MSBTTriggers.lua"


# Describe: non-CLEU trigger event registration
class NonCleuTriggerRegistrationTests(unittest.TestCase):
    def test_retired_threshold_tracker_registers_no_events(self):
        # Given the legacy trigger source.
        source = TRIGGERS_FILE.read_text(encoding="utf-8-sig")

        # When inspecting its event lifecycle.
        removed_calls = (
            "RegisterUnitEvent(", "RegisterEvent(", "UnitHealth(",
            "UnitHealthMax(", "UnitPower(", "UnitPowerMax(",
        )

        # Then health and mana cannot be polled or subscribed to.
        for call in removed_calls:
            self.assertNotIn(call, source)


if __name__ == "__main__":
    unittest.main()
