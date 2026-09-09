import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
MAIN_FILE = REPOSITORY_ROOT / "MSBTMain.lua"
OUTGOING_COMBAT_FILE = REPOSITORY_ROOT / "Components" / "OutgoingCombat.lua"
DAMAGE_METER_FILE = REPOSITORY_ROOT / "Components" / "DamageMeterSource.lua"
TOC_FILE = REPOSITORY_ROOT / "MikScrollingBattleText.toc"


# Describe: outgoing combat component integration
class OutgoingCombatIntegrationTests(unittest.TestCase):
    def test_main_uses_damage_meter_without_unit_combat_outgoing_fallback(self):
        # Given
        source = MAIN_FILE.read_text(encoding="utf-8-sig")

        # When
        uses_damage_meter = (
            "local DamageMeterSource = MikSBT.Components.DamageMeterSource"
            in source
        )

        # Then
        self.assertTrue(uses_damage_meter)
        self.assertIn(
            "local OutgoingBatcher = MikSBT.Components.OutgoingBatcher",
            source,
        )
        self.assertIn(
            "local OutgoingCombat = MikSBT.Components.OutgoingCombat",
            source,
        )
        self.assertIn("outgoingCombat:HandleSpellcastSucceeded(", source)
        self.assertNotIn("outgoingCombat:HandleUnitCombat(", source)
        self.assertIn("outgoingCombat:RecordCriticalCandidate(", source)
        self.assertIn("outgoingCombat:ConsumeCriticalCandidate(", source)
        self.assertIn("outgoingCombat:Reset()", source)
        self.assertNotIn("local outgoingBatches = {}", source)
        self.assertNotIn("local function QueueOutgoingBatch", source)
        self.assertNotIn("local function ProcessDamageMeterOutgoing", source)

    def test_components_do_not_retain_the_unit_combat_amount_fallback(self):
        # Given
        outgoing_source = OUTGOING_COMBAT_FILE.read_text(encoding="utf-8-sig")
        meter_source = DAMAGE_METER_FILE.read_text(encoding="utf-8-sig")

        # When / Then
        self.assertNotIn("function OutgoingCombat:QueueDamage(", outgoing_source)
        self.assertNotIn(
            "function OutgoingCombat:HandleUnitCombat(",
            outgoing_source,
        )
        self.assertNotIn("function DamageMeterSource:IsDeltaFresh(", meter_source)
        self.assertNotIn("lastDeltaTime", meter_source)

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
