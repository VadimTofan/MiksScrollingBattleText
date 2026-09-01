import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
MAIN_FILE = REPOSITORY_ROOT / "MSBTMain.lua"
TOC_FILE = REPOSITORY_ROOT / "MikScrollingBattleText.toc"


# Describe: incoming combat component integration
class IncomingCombatIntegrationTests(unittest.TestCase):
    def test_main_delegates_incoming_combat_ownership(self):
        # Given
        source = MAIN_FILE.read_text(encoding="utf-8-sig")

        # When / Then
        self.assertIn(
            "local IncomingCombat = MikSBT.Components.IncomingCombat",
            source,
        )
        self.assertIn(
            "local SelfHealTracker = MikSBT.Components.SelfHealTracker",
            source,
        )
        self.assertIn("local selfHealTracker = SelfHealTracker:New({", source)
        self.assertIn("local incomingCombat", source)
        self.assertIn("incomingCombat = IncomingCombat:New({", source)
        self.assertIn("incomingCombat:RecordOutgoingSelfHeal(", source)
        self.assertIn("incomingCombat:HandleUnitCombat(", source)
        self.assertIn("incomingCombat:Reset()", source)
        self.assertNotIn("local incomingDamageBatches = {}", source)
        self.assertNotIn("local incomingHealBatches = {}", source)
        self.assertNotIn("local recentOutgoingSelfHeals = {}", source)
        self.assertNotIn("local function QueueIncomingDamageBatch", source)
        self.assertNotIn("local function QueueIncomingHealBatch", source)
        self.assertNotIn("local string_upper = string.upper", source)
        self.assertNotIn("local function StripRealm", source)

    def test_incoming_component_loads_before_main(self):
        # Given
        toc_lines = TOC_FILE.read_text(encoding="utf-8-sig").splitlines()

        # When / Then
        self.assertLess(
            toc_lines.index("Components\\SelfHealTracker.lua"),
            toc_lines.index("Components\\IncomingCombat.lua"),
        )
        self.assertLess(
            toc_lines.index("Components\\IncomingCombat.lua"),
            toc_lines.index("MSBTMain.lua"),
        )


if __name__ == "__main__":
    unittest.main()
