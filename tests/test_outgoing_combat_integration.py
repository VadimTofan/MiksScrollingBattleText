import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
MAIN_FILE = REPOSITORY_ROOT / "MSBTMain.lua"
TOC_FILE = REPOSITORY_ROOT / "MikScrollingBattleText.toc"


# Describe: outgoing combat component integration
class OutgoingCombatIntegrationTests(unittest.TestCase):
    def test_main_delegates_outgoing_combat_ownership(self):
        # Given
        source = MAIN_FILE.read_text(encoding="utf-8-sig")

        # When / Then
        self.assertIn(
            "local OutgoingBatcher = MikSBT.Components.OutgoingBatcher",
            source,
        )
        self.assertIn(
            "local DamageMeterSource = MikSBT.Components.DamageMeterSource",
            source,
        )
        self.assertIn(
            "local OutgoingCombat = MikSBT.Components.OutgoingCombat",
            source,
        )
        self.assertIn("outgoingCombat:HandleSpellcastSucceeded(", source)
        self.assertIn("outgoingCombat:HandleUnitCombat(", source)
        self.assertIn("outgoingCombat:Reset()", source)
        self.assertNotIn("local outgoingBatches = {}", source)
        self.assertNotIn("local function QueueOutgoingBatch", source)
        self.assertNotIn("local function ProcessDamageMeterOutgoing", source)

    def test_outgoing_components_load_before_main(self):
        # Given
        toc_lines = TOC_FILE.read_text(encoding="utf-8-sig").splitlines()

        # When / Then
        batcher_index = toc_lines.index("Components\\OutgoingBatcher.lua")
        meter_index = toc_lines.index("Components\\DamageMeterSource.lua")
        combat_index = toc_lines.index("Components\\OutgoingCombat.lua")
        main_index = toc_lines.index("MSBTMain.lua")
        self.assertLess(batcher_index, combat_index)
        self.assertLess(meter_index, combat_index)
        self.assertLess(combat_index, main_index)


if __name__ == "__main__":
    unittest.main()
