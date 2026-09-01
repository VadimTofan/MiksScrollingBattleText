import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
LOOT_FILE = REPOSITORY_ROOT / "Components" / "LootNotifications.lua"
TOC_FILE = REPOSITORY_ROOT / "MikScrollingBattleText.toc"


# Describe: loot component integration
class TrackingComponentsIntegrationTests(unittest.TestCase):
    def test_loot_module_moved_to_components_without_api_change(self):
        # Given / When
        source = LOOT_FILE.read_text(encoding="utf-8-sig")

        # Then
        self.assertIn('local moduleName = "Loot"', source)
        self.assertIn("MikSBT[moduleName] = module", source)

    def test_loot_component_is_packaged(self):
        # Given
        toc_lines = TOC_FILE.read_text(encoding="utf-8-sig").splitlines()

        # When / Then
        self.assertIn("Components\\LootNotifications.lua", toc_lines)
        self.assertNotIn("MSBTLoot.lua", toc_lines)


if __name__ == "__main__":
    unittest.main()
