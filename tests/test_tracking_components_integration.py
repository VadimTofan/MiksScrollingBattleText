import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
COOLDOWNS_FILE = REPOSITORY_ROOT / "MSBTCooldowns.lua"
LOOT_FILE = REPOSITORY_ROOT / "Components" / "LootNotifications.lua"
TOC_FILE = REPOSITORY_ROOT / "MikScrollingBattleText.toc"


# Describe: cooldown and loot component integration
class TrackingComponentsIntegrationTests(unittest.TestCase):
    def test_cooldown_facade_owns_only_item_tracking_lifecycle(self):
        # Given
        source = COOLDOWNS_FILE.read_text(encoding="utf-8-sig")

        # When / Then
        self.assertIn(
            "local ItemCooldownTracker = MikSBT.Components.ItemCooldownTracker",
            source,
        )
        self.assertIn("local itemTracker = ItemCooldownTracker:New({", source)
        self.assertIn("itemTracker:RecordUse(", source)
        self.assertIn("itemTracker:Tick(elapsed)", source)
        self.assertNotIn("COMBAT_LOG_EVENT_UNFILTERED", source)
        self.assertNotIn("UNIT_SPELLCAST_SUCCEEDED", source)
        self.assertNotIn("local activeCooldowns", source)

    def test_loot_module_moved_to_components_without_api_change(self):
        # Given / When
        source = LOOT_FILE.read_text(encoding="utf-8-sig")

        # Then
        self.assertIn('local moduleName = "Loot"', source)
        self.assertIn("MikSBT[moduleName] = module", source)

    def test_tracking_components_load_in_dependency_order(self):
        # Given
        toc_lines = TOC_FILE.read_text(encoding="utf-8-sig").splitlines()

        # When / Then
        self.assertLess(
            toc_lines.index("Components\\ItemCooldownTracker.lua"),
            toc_lines.index("MSBTCooldowns.lua"),
        )
        self.assertIn("Components\\LootNotifications.lua", toc_lines)
        self.assertNotIn("MSBTLoot.lua", toc_lines)


if __name__ == "__main__":
    unittest.main()
